package dev.assetpipeline.androidhost

import java.nio.charset.CodingErrorAction
import java.nio.ByteBuffer

object FilePolicy {
    const val MAX_PATH = 1024
    const val MAX_DATA = 1_048_576
    fun validate(operation: Int, path: ByteArray, dataSize: Int) {
        require(operation in 1..3 && path.size in 1..MAX_PATH && dataSize in 0..MAX_DATA)
        val name = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(path)).toString()
        require(name.none { it.code < 32 || it.code == 127 || it == '\\' || it == ':' })
        val segments = name.split('/')
        require(segments.size <= 32)
        require(segments.all { it.isNotEmpty() && it != "." && it != ".." && !it.startsWith(".ap-") && it.toByteArray(Charsets.UTF_8).size <= 255 })
    }
}
