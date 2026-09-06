package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class FilePolicyTest {
    @Test fun nestedUnicodeSpaceDotfilesAndBinaryValuesAreAllowed() {
        listOf("file", "a/b/c", "雪/😀.bin", "a space/.hidden", "dots.../name").forEach {
            for (operation in 1..3) FilePolicy.validate(operation, it.toByteArray(), 0)
            FilePolicy.validate(2, it.toByteArray(), FilePolicy.MAX_DATA)
        }
    }
    @Test fun traversalUrisAbsoluteAndInternalNamesAreRejectedWithoutNormalization() {
        listOf("", "/file", "file/", "a//b", ".", "..", "a/../b", "a/./b", "C:/file", "file:///etc/passwd",
            "a\\b", "a\u0000b", "a\nb", "a\u007fb", ".ap-lock", "a/.ap-pending", "a/.ap-anything/b").forEach {
            assertThrows("Accepted unsafe path: $it", IllegalArgumentException::class.java) { FilePolicy.validate(1, it.toByteArray(), 0) }
        }
    }
    @Test fun limitsCountUtf8BytesAndDepthRatherThanCharacters() {
        FilePolicy.validate(1, "x".repeat(255).toByteArray(), 0)
        FilePolicy.validate(1, (1..32).joinToString("/") { "x" }.toByteArray(), 0)
        listOf("x".repeat(256), "😀".repeat(64), (1..33).joinToString("/") { "x" }, (1..5).joinToString("/") { "x".repeat(255) }).forEach {
            assertThrows(IllegalArgumentException::class.java) { FilePolicy.validate(1, it.toByteArray(), 0) }
        }
        assertThrows(IllegalArgumentException::class.java) { FilePolicy.validate(2, "key".toByteArray(), FilePolicy.MAX_DATA + 1) }
        assertThrows(IllegalArgumentException::class.java) { FilePolicy.validate(0, "key".toByteArray(), 0) }
        assertThrows(IllegalArgumentException::class.java) { FilePolicy.validate(4, "key".toByteArray(), 0) }
        assertThrows(IllegalArgumentException::class.java) { FilePolicy.validate(1, "key".toByteArray(), -1) }
    }
    @Test fun malformedUtf8IncludingOverlongSlashAndNulAreRejected() {
        listOf(byteArrayOf(-1), byteArrayOf(-64, -81), byteArrayOf(-64, -128), byteArrayOf(-19, -96, -128), byteArrayOf(-16, -97)).forEach {
            assertThrows(java.nio.charset.CharacterCodingException::class.java) { FilePolicy.validate(1, it, 0) }
        }
    }
}
