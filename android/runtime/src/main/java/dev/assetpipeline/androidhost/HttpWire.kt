package dev.assetpipeline.androidhost

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.Locale
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response

/** Versioned, big-endian, length-delimited bytes. No JSON/base64 expansion or
 * modified UTF-8; only metadata is text, request/response bodies are arbitrary bytes.
 */
object HttpWire {
    const val MAX_PACKET = 1_048_576
    const val MAX_BODY = 921_600
    const val MAX_HEADERS = 128
    const val MAX_HEADER_BYTES = 32_768
    data class Input(val request: Request, val timeoutMs: Int)
    private val methods = setOf("GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
    private val token = Regex("[!#$%&'*+.^_`|~0-9A-Za-z-]+")
    private val reserved = setOf("host", "connection", "content-length", "transfer-encoding", "upgrade", "expect", "proxy-authorization", "proxy-connection", "trailer", "te")

    fun decode(packet: ByteArray): Input {
        require(packet.size <= MAX_PACKET)
        val input = ByteBuffer.wrap(packet)
        fun number(): Int { require(input.remaining() >= 4); return input.int }
        fun bytes(max: Int): ByteArray {
            val size = number()
            require(size in 0..max && size <= input.remaining())
            return ByteArray(size).also { input.get(it) }
        }
        fun string(max: Int): String = Charsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes(max))).toString()
        try {
            require(number() == 1)
            val timeout = number().also { require(it in 1..120_000) }
            val method = string(16).also { require(it in methods) }
            val rawUrl = string(8192)
            require(rawUrl.all { it.code in 33..126 } && (rawUrl.startsWith("https://") || rawUrl.startsWith("http://")))
            val url = rawUrl.toHttpUrl()
            require(url.username.isEmpty() && url.password.isEmpty() && url.fragment == null)
            val builder = Request.Builder().url(url)
            val count = number().also { require(it in 0..MAX_HEADERS) }
            var headerBytes = 0
            val names = mutableSetOf<String>()
            repeat(count) {
                val name = string(MAX_HEADER_BYTES)
                val value = string(MAX_HEADER_BYTES)
                headerBytes += name.toByteArray().size + value.toByteArray().size
                require(headerBytes <= MAX_HEADER_BYTES && token.matches(name))
                require(value.all { it == '\t' || it.code in 32..126 })
                val lower = name.lowercase(Locale.ROOT)
                require(lower !in reserved && names.add(lower))
                builder.addHeader(name, value)
            }
            val size = number()
            require(size in -1..MAX_BODY && size <= input.remaining())
            val body = if (size == -1) null else ByteArray(size).also { input.get(it) }
            require(!input.hasRemaining())
            require(method !in setOf("GET", "HEAD") || body == null)
            val requiredBody = method in setOf("POST", "PUT", "PATCH")
            return Input(builder.method(method, (body ?: if (requiredBody) byteArrayOf() else null)?.toRequestBody()).build(), timeout)
        } catch (_: java.nio.charset.CharacterCodingException) {
            throw IllegalArgumentException("Invalid HTTP metadata encoding")
        }
    }

    fun encode(response: Response): ByteArray {
        val output = ByteArrayOutputStream()
        val data = DataOutputStream(output)
        fun string(value: String) {
            val bytes = value.toByteArray(Charsets.UTF_8)
            data.writeInt(bytes.size); data.write(bytes)
        }
        data.writeInt(1); data.writeInt(response.code)
        val headers = response.headers
        if (headers.size > MAX_HEADERS || headers.byteCount() > MAX_HEADER_BYTES) throw IOException("HTTP response headers exceed limit")
        data.writeInt(headers.size)
        for ((name, value) in headers) { string(name.lowercase(Locale.ROOT)); string(value) }
        val body = response.body
        if (body.contentLength() > MAX_BODY) throw IOException("HTTP response exceeds limit")
        val bytes = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        body.byteStream().use { stream ->
            while (true) {
                val size = stream.read(buffer)
                if (size == -1) break
                if (size > MAX_BODY - bytes.size()) throw IOException("HTTP response exceeds limit")
                bytes.write(buffer, 0, size)
            }
        }
        data.writeInt(bytes.size()); bytes.writeTo(data)
        if (output.size() > MAX_PACKET) throw IOException("HTTP response packet exceeds limit")
        return output.toByteArray()
    }
}
