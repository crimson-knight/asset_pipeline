package dev.assetpipeline.androidhost

import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction

/** Version 1: byte version/op, big-endian signed Int32 id, then three
 * length-prefixed UTF-8 strings. Permission packets contain only version/op. */
object NotificationWire {
    const val MAX_PACKET = 2_194
    const val MAX_CHANNEL = 128
    const val MAX_TITLE = 1_024
    // Platform Notification.Builder truncates strings above 1024 UTF-16 units.
    // A 1024-byte UTF-8 limit fits without silent platform truncation.
    const val MAX_BODY = 1_024
    data class Request(val operation: Int, val id: Int = 0, val channel: String = "", val title: String = "", val body: String = "")
    fun decode(packet: ByteArray): Request {
        require(packet.size in 2..MAX_PACKET)
        val input = ByteBuffer.wrap(packet)
        require(input.get().toInt() == 1)
        val operation = input.get().toInt()
        if (operation == 1) { require(!input.hasRemaining()); return Request(1) }
        require(operation == 2 || operation == 3)
        require(input.remaining() >= 4)
        val id = input.int
        require(id >= 0)
        if (operation == 3) { require(!input.hasRemaining()); return Request(3, id) }
        fun string(max: Int): String {
            require(input.remaining() >= 4)
            val size = input.int
            require(size in 0..max && size <= input.remaining())
            val bytes = ByteArray(size).also(input::get)
            val text = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString()
            require(!text.contains('\u0000'))
            return text
        }
        val channel = string(MAX_CHANNEL)
        require(channel.matches(Regex("[A-Za-z0-9][A-Za-z0-9_.-]{0,127}")))
        val title = string(MAX_TITLE)
        val body = string(MAX_BODY)
        require(title.isNotBlank() && !input.hasRemaining())
        return Request(2, id, channel, title, body)
    }
}
