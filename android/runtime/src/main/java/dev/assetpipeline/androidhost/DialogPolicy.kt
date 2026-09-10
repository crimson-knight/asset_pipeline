package dev.assetpipeline.androidhost

import java.security.MessageDigest

/** Value-only native alert contract; no Activity, View or callback closure. */
object DialogPolicy {
    const val MAX_PACKET_BYTES = 16_384
    fun actionTestId(base: String?, index: Int): String? {
        require(index in 0..2)
        if (base == null) return null
        val candidate = "$base.action.$index"
        if (candidate.toByteArray(Charsets.UTF_8).size <= 1024) return candidate
        val hash = MessageDigest.getInstance("SHA-256").digest(base.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
        return "ap-dialog-action:$hash:$index"
    }
    data class Action(val label: String, val style: String, val token: Long)
    data class Descriptor(val title: String, val message: String, val actions: List<Action>, val cancel: Long) {
        // Do not persist titles/messages/action labels in Android saved state.
        val signature: String get() {
            val value = buildString {
                append(title.length).append(':').append(title)
                append(message.length).append(':').append(message)
                actions.forEach { append(it.label.length).append(':').append(it.label).append(':').append(it.style) }
            }
            return MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
        }
    }
    fun validate(value: Descriptor): Descriptor {
        fun bytes(text: String) = text.toByteArray(Charsets.UTF_8).size
        require(value.title.isNotBlank() && bytes(value.title) <= 1024 && bytes(value.message) <= 8192) { "Invalid native dialog text bounds" }
        require(value.actions.size in 1..3 && value.actions.all {
            it.label.isNotBlank() && bytes(it.label) <= 512 && it.style in setOf("default", "cancel", "destructive") && it.token > 0
        } && value.actions.count { it.style == "cancel" } <= 1) { "Invalid native dialog actions" }
        require(value.cancel > 0 && (value.actions.map { it.token } + value.cancel).distinct().size == value.actions.size + 1) { "Invalid native dialog callbacks" }
        return value
    }
    /** A queued Android callback cannot reuse a dismissed/replaced window. */
    class Lease {
        var active = true
            private set
        fun consume(): Boolean = active.also { active = false }
        fun retire() { active = false }
    }
    data class Focus(val identity: String, val signature: String, val index: Int) {
        fun valid() = identity.length <= 8192 && identity.toByteArray(Charsets.UTF_8).size <= 8192 && signature.length == 64 && signature.matches(Regex("[0-9a-f]{64}")) && index in 0..2
        fun matches(key: String, descriptor: Descriptor) = valid() && key == identity && signature == descriptor.signature && index < descriptor.actions.size
    }
}
