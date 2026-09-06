package dev.assetpipeline.androidhost

import java.security.MessageDigest

/** No View, Context, application text, callbacks or native references in snapshots. */
object ViewStatePolicy {
    const val MAX_NODES = 1024
    const val MAX_ENTRIES = 256
    private fun part(value: String) = "${value.length}:$value"
    data class Identity(val kind: String, val key: String?, val scope: String, val path: String) {
        val address: String get() = part(scope) + part(kind) + if (key == null) "P${part(path)}" else "K${part(key)}"
    }
    data class Value(val keyed: Boolean, val focused: Boolean, val start: Int, val end: Int,
        val scrollX: Float, val scrollY: Float, val sensitive: Boolean = false,
        val childFocus: CompoundFocusPolicy.Locator = CompoundFocusPolicy.Locator()) {
        fun valid() = start in -1..1_000_000 && end in -1..1_000_000 &&
            scrollX.isFinite() && scrollY.isFinite() && scrollX in 0f..1_000_000f && scrollY in 0f..1_000_000f &&
            childFocus.valid() && (!childFocus.present || focused)
    }
    data class Snapshot(val route: String, val shape: String, val entries: Map<String, Value>, val ime: Boolean,
        val viewportX: Float, val viewportY: Float, val screen: String = "")

    class History {
        private val saved = ArrayDeque<Snapshot>()
        fun remember(snapshot: Snapshot) {
            saved.removeAll { it.route == snapshot.route && it.screen == snapshot.screen }
            saved.addFirst(snapshot.copy(entries = snapshot.entries.toMap()))
            while (saved.size > 8) saved.removeLast()
        }
        fun find(route: String, screen: String) = saved.firstOrNull { it.route == route && it.screen == screen }
        fun all(): List<Snapshot> = saved.toList()
        fun clear() = saved.clear()
    }

    fun validateKey(key: String) {
        require(key.isNotEmpty() && key.toByteArray(Charsets.UTF_8).size <= 256) { "View state key must contain 1..256 UTF-8 bytes" }
    }
    fun unique(identities: List<Identity>): Map<String, Identity> {
        require(identities.size <= MAX_NODES) { "Native state tree exceeds node limit" }
        return identities.groupBy { it.address }.filterValues { it.size == 1 }.mapValues { it.value.single() }
    }
    fun shape(identities: List<Identity>): String {
        require(identities.size <= MAX_NODES)
        val text = identities.joinToString("") { part(it.address) + part(it.path) }
        return digest(text)
    }
    fun screen(identities: List<Identity>): String = digest(identities.map { it.scope }.distinct().sorted().joinToString("") { part(it) })
    private fun digest(text: String) = MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    fun match(snapshot: Snapshot, route: String, identities: List<Identity>): Map<String, Value> {
        if (snapshot.route != route || snapshot.entries.size > MAX_ENTRIES) return emptyMap()
        val sameShape = snapshot.shape == shape(identities)
        return unique(identities).mapNotNull { (address, identity) ->
            snapshot.entries[address]?.takeIf { it.valid() && it.keyed == (identity.key != null) && (it.keyed || sameShape) }
                ?.let { address to it }
        }.toMap()
    }
}
