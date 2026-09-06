package dev.assetpipeline.androidhost

import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test

class NotificationWireTest {
    private fun post(id: Int = 42, channel: ByteArray = "updates".toByteArray(), title: ByteArray = "雪 😀".toByteArray(), body: ByteArray = byteArrayOf()): ByteArray {
        val buffer = ByteBuffer.allocate(18 + channel.size + title.size + body.size)
        buffer.put(1); buffer.put(2); buffer.putInt(id)
        listOf(channel, title, body).forEach { buffer.putInt(it.size); buffer.put(it) }
        return buffer.array()
    }
    @Test fun exactUtf8AndAllPacketVariants() {
        assertEquals(NotificationWire.Request(1), NotificationWire.decode(byteArrayOf(1, 1)))
        assertEquals(NotificationWire.Request(3, Int.MAX_VALUE), NotificationWire.decode(byteArrayOf(1, 3, 127, -1, -1, -1)))
        assertEquals(NotificationWire.Request(2, 42, "updates", "雪 😀", ""), NotificationWire.decode(post()))
        assertEquals(1024, NotificationWire.decode(post(channel = ByteArray(128) { 97 }, title = ByteArray(1024) { 98 }, body = ByteArray(1024) { 99 })).body.length)
    }
    @Test fun everyTruncationTrailingDataAndMalformedLengthsAreRejected() {
        val packet = post()
        packet.indices.forEach { size -> assertThrows(Exception::class.java) { NotificationWire.decode(packet.copyOf(size)) } }
        listOf(packet + 0, byteArrayOf(1, 1, 0), byteArrayOf(1, 3, 0, 0, 0, 0, 0), byteArrayOf(2, 1), byteArrayOf(1, 4), ByteArray(2195)).forEach {
            assertThrows(Exception::class.java) { NotificationWire.decode(it) }
        }
        listOf(-1, Int.MAX_VALUE).forEach { length ->
            val bad = packet.copyOf(); ByteBuffer.wrap(bad).putInt(6, length)
            assertThrows(Exception::class.java) { NotificationWire.decode(bad) }
        }
    }
    @Test fun InvalidUtf8AndBoundsFailClosed() {
        val invalid = listOf(
            post(-1), post(channel = "bad/channel".toByteArray()), post(channel = byteArrayOf()),
            post(title = byteArrayOf()), post(title = " \n".toByteArray()), post(title = byteArrayOf(0)),
            post(title = byteArrayOf(-64, -128)), post(body = byteArrayOf(-19, -96, -128)),
            post(channel = ByteArray(129) { 97 }), post(title = ByteArray(1025) { 98 }), post(body = ByteArray(1025) { 99 }),
        )
        invalid.forEach { assertThrows(Exception::class.java) { NotificationWire.decode(it) } }
    }
}
