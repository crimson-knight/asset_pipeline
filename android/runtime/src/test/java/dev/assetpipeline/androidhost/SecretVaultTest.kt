package dev.assetpipeline.androidhost

import java.nio.ByteBuffer
import javax.crypto.AEADBadTagException
import javax.crypto.KeyGenerator
import org.junit.Assert.*
import org.junit.Test

class SecretVaultTest {
    private fun key() = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()

    @Test fun boundedCodecPreservesUnicodeNulEmptyValuesAndDeterministicOrder() {
        val value = "before\u0000after 雪 😀".toByteArray()
        val first = linkedMapOf("z" to byteArrayOf(), "key\u0000😀" to value)
        val second = linkedMapOf("key\u0000😀" to value, "z" to byteArrayOf())
        val bytes = SecretVaultCodec.encode(first)
        assertArrayEquals(bytes, SecretVaultCodec.encode(second))
        val decoded = SecretVaultCodec.decode(bytes)
        assertArrayEquals(value, decoded["key\u0000😀"])
        assertArrayEquals(byteArrayOf(), decoded["z"])
        assertEquals(2, decoded.size)
        assertTrue(SecretVaultCodec.decode(SecretVaultCodec.encode(emptyMap())).isEmpty())
    }
    @Test fun everyTruncationTrailingDataDuplicateKeyAndBadUtf8AreCorruption() {
        val bytes = SecretVaultCodec.encode(mapOf("key" to "value".toByteArray()))
        bytes.indices.forEach { size -> assertThrows(SecretVaultCorrupt::class.java) { SecretVaultCodec.decode(bytes.copyOf(size)) } }
        assertThrows(SecretVaultCorrupt::class.java) { SecretVaultCodec.decode(bytes + byteArrayOf(0)) }
        val invalid = bytes.copyOf().also { it[8] = (-1).toByte() }
        assertThrows(SecretVaultCorrupt::class.java) { SecretVaultCodec.decode(invalid) }
        val duplicate = ByteBuffer.allocate(bytes.size * 2 - 4).putInt(2).put(bytes, 4, bytes.size - 4).put(bytes, 4, bytes.size - 4).array()
        assertThrows(SecretVaultCorrupt::class.java) { SecretVaultCodec.decode(duplicate) }
        val huge = bytes.copyOf().also { ByteBuffer.wrap(it).putInt(4, Int.MAX_VALUE) }
        assertThrows(SecretVaultCorrupt::class.java) { SecretVaultCodec.decode(huge) }
    }
    @Test fun inputAndAggregateLimitsAreExplicit() {
        val invalid = listOf(
            mapOf("" to byteArrayOf()), mapOf("x".repeat(513) to byteArrayOf()),
            mapOf("key" to ByteArray(65537)), (0..128).associate { "key$it" to byteArrayOf() },
            (0..15).associate { "key$it" to ByteArray(65536) },
        )
        invalid.forEach { assertThrows(IllegalArgumentException::class.java) { SecretVaultCodec.encode(it) } }
        assertThrows(java.nio.charset.CharacterCodingException::class.java) { SecretVaultCodec.encode(mapOf("key" to byteArrayOf(-1))) }
        assertArrayEquals(ByteArray(65536), SecretVaultCodec.decode(SecretVaultCodec.encode(mapOf("key" to ByteArray(65536))))["key"])
    }
    @Test fun authenticatedEncryptionUsesFreshNoncesAndHidesNamesAndValues() {
        val key = key()
        val identity = "app/vault".toByteArray()
        val plaintext = SecretVaultCodec.encode(mapOf("PRIVATE_ACCOUNT_IDENTIFIER_012345" to "PRIVATE_TOKEN_VALUE_987654".toByteArray()))
        val first = SealedSecrets.seal(key, identity, plaintext)
        val second = SealedSecrets.seal(key, identity, plaintext)
        assertFalse(first.contentEquals(second))
        assertFalse(first.copyOfRange(4, 16).contentEquals(second.copyOfRange(4, 16)))
        assertArrayEquals(plaintext, SealedSecrets.open(key, identity, first))
        assertFalse(String(first, Charsets.ISO_8859_1).contains("PRIVATE_ACCOUNT_IDENTIFIER"))
        assertFalse(String(first, Charsets.ISO_8859_1).contains("PRIVATE_TOKEN_VALUE"))
    }
    @Test fun ciphertextNonceIdentityAndKeyTamperingAreRejected() {
        val key = key()
        val identity = "app/vault".toByteArray()
        val envelope = SealedSecrets.seal(key, identity, SecretVaultCodec.encode(mapOf("key" to "value".toByteArray())))
        for (index in 4 until envelope.size) {
            val bad = envelope.copyOf().also { it[index] = (it[index].toInt() xor 1).toByte() }
            assertThrows(AEADBadTagException::class.java) { SealedSecrets.open(key, identity, bad) }
        }
        assertThrows(AEADBadTagException::class.java) { SealedSecrets.open(key, "other/vault".toByteArray(), envelope) }
        assertThrows(AEADBadTagException::class.java) { SealedSecrets.open(key(), identity, envelope) }
        val version = envelope.copyOf().also { ByteBuffer.wrap(it).putInt(0, 2) }
        assertThrows(SecretVaultCorrupt::class.java) { SealedSecrets.open(key, identity, version) }
        for (size in 0..31) assertThrows(SecretVaultCorrupt::class.java) { SealedSecrets.open(key, identity, envelope.copyOf(size)) }
        assertThrows(SecretVaultCorrupt::class.java) { SealedSecrets.open(key, identity, ByteArray(SealedSecrets.MAX_ENVELOPE + 1)) }
    }
}
