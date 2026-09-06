package dev.assetpipeline.androidhost

import java.security.MessageDigest

/** A bounded structural locator, not native IDs or saved option strings. */
object CompoundFocusPolicy {
    const val MAX_OPTIONS = 256
    data class Locator(val index: Int = -1, val signature: String = "") {
        fun valid() = index == -1 && signature.isEmpty() || index in 0 until MAX_OPTIONS && signature.matches(Regex("[0-9a-f]{64}"))
        val present get() = index >= 0
    }
    fun signature(options: List<String>): String? {
        if (options.isEmpty() || options.size > MAX_OPTIONS || options.any { it.length > 4096 }) return null
        val bytes = options.map { it.toByteArray(Charsets.UTF_8) }
        if (bytes.sumOf { it.size } > 32_768) return null
        val digest = MessageDigest.getInstance("SHA-256")
        // Length framing distinguishes a,b from ab, and preserves Unicode/NUL.
        for (value in bytes) {
            digest.update("${value.size}:".toByteArray(Charsets.US_ASCII))
            digest.update(value)
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
    fun matches(locator: Locator, options: List<String>) = locator.valid() && locator.present &&
        locator.index in options.indices && signature(options) == locator.signature
}
