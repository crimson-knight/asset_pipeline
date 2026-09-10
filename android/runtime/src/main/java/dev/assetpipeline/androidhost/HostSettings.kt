package dev.assetpipeline.androidhost

import java.util.concurrent.ConcurrentHashMap

/** Settings the host application bakes into its build and hands to Crystal
 * before the first render: the Android side of the keys an iOS host reads
 * from Info.plist (a demo id, a display name, a palette). Keys are 1 to 64
 * characters of `[A-Za-z0-9_.]`, values UTF-8 up to 4096 bytes; a later
 * registration replaces an earlier value under the same key. Crystal reads
 * them through `UI::Android::Application.setting`. */
object HostSettings {
    const val MAX_KEY = 64
    const val MAX_VALUE = 4096
    private val keyPattern = Regex("[A-Za-z0-9_.]{1,$MAX_KEY}")
    private val values = ConcurrentHashMap<String, String>()

    @JvmStatic fun validKey(key: String): Boolean = keyPattern.matches(key)

    /** Registers one setting; false, and no change, when the key or the value is out of contract. */
    @JvmStatic fun register(key: String, value: String): Boolean {
        if (!validKey(key) || value.toByteArray(Charsets.UTF_8).size > MAX_VALUE) return false
        values[key] = value
        return true
    }

    /** Registers every entry that is in contract; returns how many were. */
    @JvmStatic fun register(settings: Map<String, String>): Int = settings.count { register(it.key, it.value) }

    /** Parses `KEY=value` lines and registers them; returns how many were in contract. */
    @JvmStatic fun registerSerialized(text: String): Int = register(parse(text))

    /** One `KEY=value` per line. Blank lines and lines starting with `#` are
     * skipped, the first `=` splits, both sides are trimmed, and a line with
     * no `=` or an empty key is skipped. Values keep their inner spaces. */
    @JvmStatic fun parse(text: String): Map<String, String> {
        val out = LinkedHashMap<String, String>()
        for (raw in text.lineSequence()) {
            val line = raw.trim()
            if (line.isEmpty() || line.startsWith("#")) continue
            val split = line.indexOf('=')
            if (split <= 0) continue
            val key = line.substring(0, split).trim()
            if (key.isEmpty()) continue
            out[key] = line.substring(split + 1).trim()
        }
        return out
    }

    /** The value under a UTF-8 key as UTF-8, or null when none is registered. */
    @JvmStatic fun valueBytes(key: ByteArray): ByteArray? = values[String(key, Charsets.UTF_8)]?.toByteArray(Charsets.UTF_8)

    @JvmStatic fun keys(): List<String> = values.keys.sorted()

    @JvmStatic fun clear() = values.clear()
}
