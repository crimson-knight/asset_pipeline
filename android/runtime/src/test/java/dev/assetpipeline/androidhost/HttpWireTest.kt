package dev.assetpipeline.androidhost

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.nio.ByteBuffer
import okhttp3.Response
import okhttp3.Protocol
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.*
import org.junit.Test

class HttpWireTest {
    companion object {
        fun packet(url: String = "https://localhost/", method: String = "GET", headers: List<Pair<String, String>> = emptyList(), body: ByteArray? = null, timeout: Int = 1000): ByteArray {
            val bytes = ByteArrayOutputStream()
            val out = DataOutputStream(bytes)
            fun string(value: String) { val data = value.toByteArray(); out.writeInt(data.size); out.write(data) }
            out.writeInt(1); out.writeInt(timeout); string(method); string(url)
            out.writeInt(headers.size)
            headers.forEach { (key, value) -> string(key); string(value) }
            out.writeInt(body?.size ?: -1); body?.let(out::write)
            return bytes.toByteArray()
        }
    }
    @Test fun requestPreservesBinaryBodyAndExplicitHeaders() {
        val input = HttpWire.decode(packet(method = "PATCH", body = byteArrayOf(0, -1, 42), headers = listOf("Authorization" to "Bearer test")))
        val bytes = okio.Buffer()
        input.request.body!!.writeTo(bytes)
        assertArrayEquals(byteArrayOf(0, -1, 42), bytes.readByteArray())
        assertEquals("PATCH", input.request.method)
        assertEquals("Bearer test", input.request.header("authorization"))
        assertEquals(1000, input.timeoutMs)
        assertEquals(0L, HttpWire.decode(packet(method = "POST")).request.body!!.contentLength())
    }
    @Test fun malformedOrAmbiguousRequestsAreRejectedBeforeConnecting() {
        val bad = listOf(
            byteArrayOf(), packet() + byteArrayOf(1), packet(timeout = 0), packet(timeout = 120001),
            packet(url = "file:///private"), packet(url = "https://user:secret@localhost/"), packet(url = "https://localhost/#token"),
            packet(url = "https://localhost/\nprivate"), packet(method = "TRACE"), packet(method = "get"),
            packet(body = byteArrayOf()), packet(method = "POST", body = ByteArray(HttpWire.MAX_BODY + 1)),
            packet(headers = listOf("Bad Header" to "x")), packet(headers = listOf("X-Test" to "a\r\nInjected: 1")),
            packet(headers = listOf("Host" to "different")), packet(headers = listOf("Content-Length" to "0")),
            packet(headers = listOf("X-Test" to "a", "x-test" to "b")),
            packet(headers = List(129) { "X-$it" to "a" }), packet(headers = listOf("X-Test" to "x".repeat(32768))),
        )
        bad.forEachIndexed { index, data -> assertThrows("Invalid request $index", IllegalArgumentException::class.java) { HttpWire.decode(data) } }
    }
    @Test fun truncationInvalidUtf8AndHostileLengthsAreRejected() {
        val original = packet(method = "PUT", body = byteArrayOf(0, -1, 2))
        for (size in original.indices) assertThrows(IllegalArgumentException::class.java) { HttpWire.decode(original.copyOf(size)) }
        val badLength = original.copyOf().also { ByteBuffer.wrap(it).putInt(8, Int.MAX_VALUE) }
        assertThrows(IllegalArgumentException::class.java) { HttpWire.decode(badLength) }
        val invalid = original.copyOf().also { it[12] = 0xff.toByte() }
        assertThrows(IllegalArgumentException::class.java) { HttpWire.decode(invalid) }
    }
    @Test fun responseKeepsRepeatedHeadersAndBoundsUnknownLengthBodies() {
        val request = HttpWire.decode(packet()).request
        fun response(body: ByteArray) = Response.Builder().request(request).protocol(Protocol.HTTP_1_1).code(422).message("Invalid")
            .addHeader("Set-Cookie", "one=1").addHeader("Set-Cookie", "two=2").body(body.toResponseBody()).build()
        response(byteArrayOf(0, -1)).use {
            val data = ByteBuffer.wrap(HttpWire.encode(it))
            assertEquals(1, data.int); assertEquals(422, data.int); assertEquals(2, data.int)
            fun string(): String { val size = data.int; return String(ByteArray(size).also { data.get(it) }) }
            assertEquals("set-cookie", string()); assertEquals("one=1", string())
            assertEquals("set-cookie", string()); assertEquals("two=2", string())
            assertEquals(2, data.int); assertEquals(0.toByte(), data.get()); assertEquals((-1).toByte(), data.get())
            assertFalse(data.hasRemaining())
        }
        response(ByteArray(HttpWire.MAX_BODY + 1)).use { assertThrows(java.io.IOException::class.java) { HttpWire.encode(it) } }
    }
}
