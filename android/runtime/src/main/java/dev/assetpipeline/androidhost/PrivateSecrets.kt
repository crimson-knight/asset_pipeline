package dev.assetpipeline.androidhost

import android.content.Context
import android.os.Looper
import android.os.UserManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.system.Os
import android.system.OsConstants
import android.util.AtomicFile
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/** App-scoped, credential-encrypted, no-backup vault. All directory, key and
 * cryptographic work is lazy and off the main looper. No biometric prompt or
 * guaranteed hardware backing is implied by this background-capable service.
 */
class PrivateSecrets(context: Context, private val name: String = "asset_pipeline_secrets_v1") {
    private val app = context.applicationContext
    internal val keyAlias = "dev.assetpipeline.secrets.v1.$name"
    private val identity = "AssetPipeline secrets v1\u0000${app.packageName}\u0000$name".toByteArray(Charsets.UTF_8)
    init { require(name.matches(Regex("[A-Za-z0-9_-]{1,64}"))) }

    private class KeyUnavailable : GeneralSecurityException()

    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (store.containsAlias(keyAlias)) return store.getKey(keyAlias, null) as? SecretKey ?: throw KeyUnavailable()
        // An existing vault without its key is NOT a new installation. Never
        // replace its key or erase its ciphertext to make a failed read succeed.
        if (!create) throw KeyUnavailable()
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true).setUserAuthenticationRequired(false).build())
        return generator.generateKey()
    }

    private fun read(file: AtomicFile): ByteArray = file.openRead().use { input ->
        val bytes = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val size = input.read(buffer)
            if (size == -1) break
            if (size > SealedSecrets.MAX_ENVELOPE - bytes.size()) throw SecretVaultCorrupt()
            bytes.write(buffer, 0, size)
        }
        bytes.toByteArray()
    }

    private fun write(file: AtomicFile, directory: File, ciphertext: ByteArray) {
        val output = file.startWrite()
        try {
            output.write(ciphertext)
            output.fd.sync()
            file.finishWrite(output)
        } catch (error: Exception) {
            file.failWrite(output)
            throw error
        }
        // AtomicFile logs some rename failures instead of throwing. Verify the
        // committed envelope and sync its directory before acknowledging success.
        if (!java.security.MessageDigest.isEqual(read(file), ciphertext)) throw IOException("Protected storage commit failed")
        val fd = Os.open(directory.absolutePath, OsConstants.O_RDONLY, 0)
        try {
            if (!OsConstants.S_ISDIR(Os.fstat(fd).st_mode)) throw IOException("Invalid protected storage directory")
            Os.fsync(fd)
        } finally { Os.close(fd) }
    }

    fun execute(operation: Int, keyBytes: ByteArray, value: ByteArray): ServiceReply {
        check(Looper.myLooper() != Looper.getMainLooper()) { "Secrets must run off the main looper" }
        if (operation !in 1..3 || keyBytes.isEmpty() || keyBytes.size > SecretVaultCodec.MAX_KEY || value.size > SecretVaultCodec.MAX_VALUE) return ServiceReply(ServiceStatus.INVALID_INPUT)
        val name = try {
            if (operation == 2) SecretVaultCodec.utf8(value)
            SecretVaultCodec.utf8(keyBytes)
        } catch (_: Exception) { return ServiceReply(ServiceStatus.INVALID_INPUT) }
        if (app.isDeviceProtectedStorage || !app.getSystemService(UserManager::class.java).isUserUnlocked) return ServiceReply(ServiceStatus.UNAVAILABLE)
        return try {
            val parent = app.noBackupFilesDir
            val directory = File(parent, this.name)
            if (Files.isSymbolicLink(directory.toPath()) || directory.canonicalFile.parentFile != parent.canonicalFile) throw IOException("Invalid protected storage directory")
            if (!directory.isDirectory && !directory.mkdir()) throw IOException("Protected storage directory unavailable")
            val base = File(directory, "vault.bin")
            val lock = File(directory, "vault.lock")
            for (file in listOf(base, lock, File(directory, "vault.bin.bak"), File(directory, "vault.bin.new"))) {
                if (Files.isSymbolicLink(file.toPath()) || (file.exists() && !file.isFile)) throw IOException("Invalid protected storage file")
            }
            FileOutputStream(lock, true).channel.use { channel -> channel.lock().use locked@ {
                val file = AtomicFile(base)
                val exists = base.exists() || File(directory, "vault.bin.bak").exists()
                if (!exists && operation != 2) return@locked ServiceReply(if (operation == 1) ServiceStatus.NOT_FOUND else ServiceStatus.OK)
                val secretKey = key(create = !exists)
                val entries = if (exists) SecretVaultCodec.decode(SealedSecrets.open(secretKey, identity, read(file))) else mutableMapOf()
                when (operation) {
                    1 -> entries[name]?.let { ServiceReply(ServiceStatus.OK, it) } ?: ServiceReply(ServiceStatus.NOT_FOUND)
                    else -> {
                        if (operation == 2) entries[name] = value else entries.remove(name)
                        val plaintext = try { SecretVaultCodec.encode(entries) } catch (_: IllegalArgumentException) { return@locked ServiceReply(ServiceStatus.INVALID_INPUT) }
                        write(file, directory, SealedSecrets.seal(secretKey, identity, plaintext))
                        ServiceReply(ServiceStatus.OK)
                    }
                }
            } }
        } catch (_: AEADBadTagException) { ServiceReply(ServiceStatus.IO)
        } catch (_: GeneralSecurityException) { ServiceReply(ServiceStatus.UNAVAILABLE)
        } catch (_: SecurityException) { ServiceReply(ServiceStatus.PERMISSION_DENIED)
        } catch (_: Exception) { ServiceReply(ServiceStatus.IO) }
    }
}
