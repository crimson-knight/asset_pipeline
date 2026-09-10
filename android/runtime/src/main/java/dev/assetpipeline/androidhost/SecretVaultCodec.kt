package dev.assetpipeline.androidhost

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction

class SecretVaultCorrupt : IOException("Protected storage is damaged")

/** Plaintext exists only in memory. Both identifiers and values are sealed by
 * the backend as one authenticated vault; no plaintext index is written to disk.
 */
object SecretVaultCodec {
    const val MAX_KEY = 512
    const val MAX_VALUE = 65_536
    const val MAX_ENTRIES = 128
    const val MAX_PLAINTEXT = 1_000_000

    fun utf8(bytes: ByteArray): String = Charsets.UTF_8.newDecoder()
        .onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
        .decode(ByteBuffer.wrap(bytes)).toString()

    fun encode(entries: Map<String, ByteArray>): ByteArray {
        require(entries.size <= MAX_ENTRIES)
        var size = 4L
        entries.forEach { (key, value) ->
            val bytes = key.toByteArray(Charsets.UTF_8)
            require(bytes.isNotEmpty() && bytes.size <= MAX_KEY && value.size <= MAX_VALUE)
            require(utf8(bytes) == key)
            utf8(value)
            size += 8L + bytes.size + value.size
        }
        require(size <= MAX_PLAINTEXT)
        val bytes = ByteArrayOutputStream(size.toInt())
        val output = DataOutputStream(bytes)
        output.writeInt(entries.size)
        entries.toSortedMap().forEach { (key, value) ->
            val name = key.toByteArray(Charsets.UTF_8)
            output.writeInt(name.size); output.write(name)
            output.writeInt(value.size); output.write(value)
        }
        return bytes.toByteArray()
    }

    fun decode(bytes: ByteArray): MutableMap<String, ByteArray> {
        try {
            require(bytes.size <= MAX_PLAINTEXT)
            val input = ByteBuffer.wrap(bytes)
            fun number(): Int { require(input.remaining() >= 4); return input.int }
            fun field(max: Int): ByteArray {
                val size = number()
                require(size in 0..max && size <= input.remaining())
                return ByteArray(size).also { input.get(it) }
            }
            val count = number().also { require(it in 0..MAX_ENTRIES) }
            val entries = mutableMapOf<String, ByteArray>()
            repeat(count) {
                val key = utf8(field(MAX_KEY)).also { require(it.isNotEmpty() && !entries.containsKey(it)) }
                val value = field(MAX_VALUE).also { utf8(it) }
                entries[key] = value
            }
            require(!input.hasRemaining())
            return entries
        } catch (_: Exception) { throw SecretVaultCorrupt() }
    }
}
