package dev.assetpipeline.androidhost

import java.nio.ByteBuffer
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Standard AES-256-GCM, not a custom cipher. AndroidKeyStore generates the
 * random nonce on every encryption. The envelope version and app/vault identity
 * are authenticated; unknown versions or authentication failure never reset data.
 */
object SealedSecrets {
    private const val VERSION = 1
    private const val NONCE_SIZE = 12
    private const val TAG_BITS = 128
    const val MAX_ENVELOPE = SecretVaultCodec.MAX_PLAINTEXT + 32

    fun seal(key: SecretKey, identity: ByteArray, plaintext: ByteArray): ByteArray {
        require(plaintext.size <= SecretVaultCodec.MAX_PLAINTEXT)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val version = ByteBuffer.allocate(4).putInt(VERSION).array()
        cipher.updateAAD(version); cipher.updateAAD(identity)
        val ciphertext = cipher.doFinal(plaintext)
        check(cipher.iv.size == NONCE_SIZE)
        return ByteBuffer.allocate(4 + NONCE_SIZE + ciphertext.size).put(version).put(cipher.iv).put(ciphertext).array()
    }

    fun open(key: SecretKey, identity: ByteArray, envelope: ByteArray): ByteArray {
        if (envelope.size !in 32..MAX_ENVELOPE) throw SecretVaultCorrupt()
        val bytes = ByteBuffer.wrap(envelope)
        if (bytes.int != VERSION) throw SecretVaultCorrupt()
        val nonce = ByteArray(NONCE_SIZE).also { bytes.get(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, nonce))
        cipher.updateAAD(envelope, 0, 4); cipher.updateAAD(identity)
        return cipher.doFinal(envelope, 4 + NONCE_SIZE, envelope.size - 4 - NONCE_SIZE)
    }
}
