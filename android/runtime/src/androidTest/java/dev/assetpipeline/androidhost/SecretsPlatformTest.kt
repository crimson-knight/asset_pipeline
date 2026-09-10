package dev.assetpipeline.androidhost

import android.content.Context
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.nio.file.Files
import java.security.KeyStore
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

@RunWith(AndroidJUnit4::class)
class SecretsPlatformTest {
    private fun withVault(block: (Context, String, PrivateSecrets, File) -> Unit) {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val name = "ap_secret_test_${UUID.randomUUID()}"
        val worker = Executors.newSingleThreadExecutor()
        try {
            worker.submit {
                val vault = PrivateSecrets(context, name)
                val directory = File(context.noBackupFilesDir, name)
                try { block(context, name, vault, directory) } finally {
                    val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                    keys.deleteEntry(vault.keyAlias)
                    // Only this test's random, app-private namespace is removed.
                    assertEquals(context.noBackupFilesDir.canonicalFile, requireNotNull(directory.absoluteFile.parentFile).canonicalFile)
                    if (Files.isSymbolicLink(directory.toPath())) Files.delete(directory.toPath()) else directory.deleteRecursively()
                }
            }.get(30, TimeUnit.SECONDS)
        } finally { worker.shutdown(); assertTrue(worker.awaitTermination(30, TimeUnit.SECONDS)) }
    }

    @Test fun realKeystoreIsNonExportableAndNamesAndValuesStayEncryptedAcrossReopen() = withVault { context, name, vault, directory ->
        val key = "PRIVATE_IDENTIFIER_雪_😀\u0000end".toByteArray()
        val value = "PRIVATE_VALUE_雪_😀\u0000end".toByteArray()
        assertEquals(ServiceStatus.NOT_FOUND, vault.execute(1, key, byteArrayOf()).status)
        val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        assertFalse("Reads must not create encryption keys", keys.containsAlias(vault.keyAlias))
        assertEquals(ServiceStatus.OK, vault.execute(2, key, value).status)
        val secretKey = keys.getKey(vault.keyAlias, null) as SecretKey
        assertNull(secretKey.encoded)
        val info = SecretKeyFactory.getInstance("AES", "AndroidKeyStore").getKeySpec(secretKey, KeyInfo::class.java) as KeyInfo
        assertEquals(256, info.keySize)
        assertTrue(info.blockModes.contains(KeyProperties.BLOCK_MODE_GCM))
        assertFalse(info.isUserAuthenticationRequired)
        val file = File(directory, "vault.bin")
        val original = file.readBytes()
        assertEquals(context.noBackupFilesDir.canonicalFile, directory.canonicalFile.parentFile)
        assertFalse(String(original, Charsets.ISO_8859_1).contains("PRIVATE_IDENTIFIER"))
        assertFalse(String(original, Charsets.ISO_8859_1).contains("PRIVATE_VALUE"))
        assertArrayEquals(value, PrivateSecrets(context, name).execute(1, key, byteArrayOf()).data)
        assertEquals(ServiceStatus.OK, vault.execute(2, key, value).status)
        assertFalse(original.contentEquals(file.readBytes()))
        assertEquals(ServiceStatus.INVALID_INPUT, vault.execute(2, key, byteArrayOf(-1)).status)
        assertArrayEquals(value, vault.execute(1, key, byteArrayOf()).data)
        assertEquals(ServiceStatus.OK, vault.execute(2, key, byteArrayOf()).status)
        assertEquals(ServiceStatus.OK, vault.execute(1, key, byteArrayOf()).status)
        assertTrue(vault.execute(1, key, byteArrayOf()).data.isEmpty())
        assertEquals(ServiceStatus.OK, vault.execute(3, key, byteArrayOf()).status)
        assertEquals(ServiceStatus.NOT_FOUND, vault.execute(1, key, byteArrayOf()).status)
        assertEquals(ServiceStatus.OK, vault.execute(3, key, byteArrayOf()).status)
    }

    @Test fun tamperingFailsClosedAndPreservesCiphertextOnReadWriteAndDelete() = withVault { _, _, vault, directory ->
        val key = "key".toByteArray()
        assertEquals(ServiceStatus.OK, vault.execute(2, key, "test-only-value".toByteArray()).status)
        val file = File(directory, "vault.bin")
        val tampered = file.readBytes().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() }
        file.writeBytes(tampered)
        for (operation in 1..3) {
            assertEquals(ServiceStatus.IO, vault.execute(operation, key, "replacement".toByteArray()).status)
            assertArrayEquals(tampered, file.readBytes())
        }
    }

    @Test fun losingTheKeystoreKeyNeverCreatesAReplacementOrErasesTheVault() = withVault { context, name, vault, directory ->
        val key = "key".toByteArray()
        assertEquals(ServiceStatus.OK, vault.execute(2, key, "test-only-value".toByteArray()).status)
        val file = File(directory, "vault.bin")
        val original = file.readBytes()
        val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        keys.deleteEntry(vault.keyAlias)
        for (operation in 1..3) {
            assertEquals(ServiceStatus.UNAVAILABLE, PrivateSecrets(context, name).execute(operation, key, "replacement".toByteArray()).status)
            assertFalse(keys.containsAlias(vault.keyAlias))
            assertArrayEquals(original, file.readBytes())
        }
    }

    @Test fun interruptedAtomicWriteRecoversThePreviousAuthenticatedEnvelope() = withVault { _, _, vault, directory ->
        val key = "key".toByteArray()
        assertEquals(ServiceStatus.OK, vault.execute(2, key, "original".toByteArray()).status)
        val base = File(directory, "vault.bin")
        val original = base.readBytes()
        assertEquals(ServiceStatus.OK, vault.execute(2, key, "new-value".toByteArray()).status)
        File(directory, "vault.bin.bak").writeBytes(original)
        File(directory, "vault.bin.new").writeBytes(byteArrayOf(1, 2, 3))
        assertArrayEquals("original".toByteArray(), vault.execute(1, key, byteArrayOf()).data)
        assertArrayEquals(original, base.readBytes())
    }

    @Test fun invalidPathsAndInputDoNotEscapeOrReplaceTheVault() = withVault { _, _, vault, directory ->
        val key = "key".toByteArray()
        assertEquals(ServiceStatus.INVALID_INPUT, vault.execute(1, byteArrayOf(), byteArrayOf()).status)
        assertEquals(ServiceStatus.INVALID_INPUT, vault.execute(2, key, ByteArray(65537)).status)
        assertEquals(ServiceStatus.OK, vault.execute(2, key, "original".toByteArray()).status)
        val original = File(directory, "vault.bin").readBytes()
        val lock = File(directory, "vault.lock")
        assertTrue(lock.delete()); assertTrue(lock.mkdir())
        assertEquals(ServiceStatus.IO, vault.execute(2, key, "replacement".toByteArray()).status)
        assertArrayEquals(original, File(directory, "vault.bin").readBytes())
        assertTrue(lock.delete())
        val sentinel = File(directory, "untouched-test-target").apply { writeBytes("untouched".toByteArray()) }
        for (filename in listOf("vault.bin", "vault.lock", "vault.bin.bak", "vault.bin.new")) {
            val path = File(directory, filename).toPath()
            val saved = File(directory, "saved-$filename").toPath()
            val existed = Files.exists(path)
            if (existed) Files.move(path, saved)
            try {
                Files.createSymbolicLink(path, sentinel.toPath())
                for (operation in 1..3) assertEquals(ServiceStatus.IO, vault.execute(operation, key, "replacement".toByteArray()).status)
                assertArrayEquals("untouched".toByteArray(), sentinel.readBytes())
            } finally {
                Files.deleteIfExists(path)
                if (existed) Files.move(saved, path)
            }
            assertArrayEquals(original, File(directory, "vault.bin").readBytes())
        }
    }
}
