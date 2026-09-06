package dev.assetpipeline.androidhost

import android.os.Bundle
import android.os.Looper
import android.os.Parcel
import android.text.method.PasswordTransformationMethod
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.ScrollView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.util.ArrayDeque
import java.util.UUID

/** Metadata is owned by each native View; snapshots contain only bounded values. */
object NativeViewState {
    const val MAX_SAVED_BYTES = 196_608
    /** Only resource limits use this exception; configuration/native failures remain fatal. */
    class BudgetExceeded : RuntimeException("Native view state exceeds its metadata budget")
    private val processIdentity = UUID.randomUUID().toString()
    private fun budget(ok: Boolean) { if (!ok) throw BudgetExceeded() }
    private data class Metadata(val key: String?, val kind: String, val screen: String?)
    data class Node(val view: View, val identity: ViewStatePolicy.Identity, val editor: EditText?)
    private fun main() = check(Looper.myLooper() == Looper.getMainLooper()) { "Native view state requires the main looper" }
    private fun tagId(view: View): Int = view.resources.getIdentifier("ap_native_view_state", "id", view.context.packageName).also {
        check(it != 0) { "Host must include canonical Android runtime resources" }
    }
    @JvmStatic fun mark(view: View, key: String, kind: String, screen: String) {
        main()
        if (key.isNotEmpty()) ViewStatePolicy.validateKey(key)
        require(kind.isNotEmpty() && kind.length <= 128 && screen.toByteArray(Charsets.UTF_8).size <= 512)
        // Crystal's monotonically allocated identities are process-local. A
        // fresh process must not match a recycled allocation sequence saved by
        // its predecessor. Explicit application screen keys remain portable.
        val scopedScreen = if (screen.startsWith("process:")) "$processIdentity:$screen" else screen
        view.setTag(tagId(view), Metadata(key.ifEmpty { null }, kind, scopedScreen.ifEmpty { null }))
    }
    private fun editor(view: View): EditText? {
        return NativeSemantics.target(view) as? EditText
    }
    private fun part(value: String) = "${value.length}:$value"
    fun nodes(root: View): List<Node> {
        main()
        data class Work(val view: View, val parent: String, val scope: String, val depth: Int)
        val pending = ArrayDeque<Work>()
        val counters = mutableMapOf<String, Int>()
        val result = mutableListOf<Node>()
        pending.add(Work(root, "", "", 0))
        val tag = tagId(root)
        var visited = 0
        while (pending.isNotEmpty()) {
            val work = pending.removeLast()
            budget(++visited <= 8192 && work.depth <= 128)
            var parent = work.parent
            var scope = work.scope
            val metadata = work.view.getTag(tag) as? Metadata
            if (metadata != null) {
                val index = counters[parent] ?: 0
                counters[parent] = index + 1
                val path = "$parent.$index"
                if (metadata.screen != null) scope += part(metadata.key ?: path) + part(metadata.screen)
                else if (parent.isEmpty() && metadata.key != null) scope += part(metadata.key)
                budget(scope.toByteArray(Charsets.UTF_8).size <= 4096 && result.size < ViewStatePolicy.MAX_NODES)
                result.add(Node(work.view, ViewStatePolicy.Identity(metadata.kind, metadata.key, scope, path), editor(work.view)))
                parent = path
            }
            // Sheet contents have their own window/metadata snapshot. Including
            // them here would change the underlying shape when reparented.
            if (work.view is ViewGroup && work.view !is NativeSheetAnchor) for (i in work.view.childCount - 1 downTo 0)
                pending.add(Work(work.view.getChildAt(i), parent, scope, work.depth + 1))
        }
        return result
    }
    private fun horizontal(view: View): View = if (view is ScrollView && view.childCount == 1 && view.getChildAt(0) is HorizontalScrollView) view.getChildAt(0) else view
    private fun density(view: View) = view.resources.displayMetrics.density
    private fun safeDp(value: Int, view: View) = (value / density(view)).coerceIn(0f, 1_000_000f)
    private fun visibleInside(view: View, root: View): Boolean {
        // isShown() includes the Activity's window/decor. The host captures an
        // existing tree in onStart, before that window is visible again. Only
        // application visibility inside the mounted tree determines whether
        // its presentation state should be retained across a stopped window.
        var current: View? = view
        while (current != null) {
            if (current.visibility != View.VISIBLE) return false
            if (current === root) return true
            current = current.parent as? View
        }
        return false
    }
    fun capture(root: View, route: String, viewport: View? = null): ViewStatePolicy.Snapshot {
        main()
        budget(route.toByteArray(Charsets.UTF_8).size <= 4096)
        val nodes = nodes(root)
        val identities = nodes.map { it.identity }
        val unique = ViewStatePolicy.unique(identities)
        val entries = linkedMapOf<String, ViewStatePolicy.Value>()
        var bytes = 0
        for (node in nodes.sortedByDescending { NativeCompoundFocus.target(it.view).isFocused }) {
            val id = node.identity
            if (id.address !in unique || !visibleInside(node.view, root) || !node.view.isEnabled) continue
            val editor = node.editor
            val focusTarget = NativeCompoundFocus.target(node.view)
            if (editor == null && !focusTarget.isFocusable && node.view !is ScrollView && node.view !is HorizontalScrollView) continue
            bytes += id.address.toByteArray(Charsets.UTF_8).size
            if (bytes > 32_768 || entries.size >= ViewStatePolicy.MAX_ENTRIES) break
            val childFocus = NativeCompoundFocus.capture(node.view)
            // An unmodeled/over-budget compound cannot fall back to focusing a
            // different selected option just because it still has focus now.
            val focused = focusTarget.isFocused && (focusTarget === NativeSemantics.target(node.view) || childFocus.present)
            entries[id.address] = ViewStatePolicy.Value(id.key != null, focused,
                editor?.selectionStart ?: -1, editor?.selectionEnd ?: -1,
                safeDp(horizontal(node.view).scrollX, node.view), safeDp(node.view.scrollY, node.view), editor?.transformationMethod is PasswordTransformationMethod, childFocus)
        }
        return ViewStatePolicy.Snapshot(route, ViewStatePolicy.shape(identities), entries,
            ViewCompat.getRootWindowInsets(root)?.isVisible(WindowInsetsCompat.Type.ime()) == true,
            viewport?.let { safeDp(it.scrollX, it) } ?: 0f, viewport?.let { safeDp(it.scrollY, it) } ?: 0f, ViewStatePolicy.screen(identities))
    }
    /** Returns a focused editor, if any; the host controls keyboard presentation. */
    fun restore(root: View, route: String, saved: ViewStatePolicy.Snapshot, viewport: View? = null, restoreFocus: Boolean = true): Pair<Int, EditText?> {
        val nodes = nodes(root)
        val identities = nodes.map { it.identity }
        val matched = ViewStatePolicy.match(saved, route, identities)
        var focused: View? = null
        var restored = 0
        for (node in nodes) {
            val value = matched[node.identity.address] ?: continue
            if (!node.view.isShown || !node.view.isEnabled) continue
            val edit = node.editor
            if (restoreFocus && value.focused && focused == null && NativeCompoundFocus.restore(node.view, value.childFocus)) focused = NativeCompoundFocus.target(node.view)
            if (edit != null && edit.isEnabled && edit.isFocusable) {
                if (value.start >= 0 && value.end >= 0) edit.setSelection(value.start.coerceAtMost(edit.text.length), value.end.coerceAtMost(edit.text.length))
            }
            restored++
        }
        // Focus may request a parent scroll. Restore the intended viewport last.
        for (node in nodes) {
            val value = matched[node.identity.address] ?: continue
            if (!node.view.isShown || !node.view.isEnabled) continue
            if (node.view is ScrollView || node.view is HorizontalScrollView) {
                horizontal(node.view).scrollTo(LayoutPolicy.pixels(value.scrollX, density(node.view)), 0)
                node.view.scrollTo(if (node.view is HorizontalScrollView) LayoutPolicy.pixels(value.scrollX, density(node.view)) else 0,
                    LayoutPolicy.pixels(value.scrollY, density(node.view)))
            }
        }
        if (saved.route == route && saved.screen == ViewStatePolicy.screen(identities)) viewport?.scrollTo(
            LayoutPolicy.pixels(saved.viewportX, density(viewport)), LayoutPolicy.pixels(saved.viewportY, density(viewport)))
        return restored to (focused as? EditText)
    }
    fun toBundle(saved: ViewStatePolicy.Snapshot): Bundle {
        main()
        budget(saved.route.toByteArray(Charsets.UTF_8).size <= 4096 &&
            saved.shape.matches(Regex("[0-9a-f]{64}")) && saved.screen.matches(Regex("[0-9a-f]{64}")) &&
            saved.entries.size <= ViewStatePolicy.MAX_ENTRIES &&
            saved.entries.keys.sumOf { it.toByteArray(Charsets.UTF_8).size.toLong() } <= 32_768L &&
            saved.entries.values.all { it.valid() } &&
            saved.viewportX.isFinite() && saved.viewportY.isFinite() &&
            saved.viewportX in 0f..1_000_000f && saved.viewportY in 0f..1_000_000f)
        return Bundle().apply {
            putInt("version", 1); putString("route", saved.route); putString("shape", saved.shape); putString("screen", saved.screen)
            putBoolean("ime", saved.ime); putFloat("x", saved.viewportX); putFloat("y", saved.viewportY)
            val keys = ArrayList<String>()
            for ((key, value) in saved.entries) {
                if (!value.valid()) continue
                val index = keys.size
                keys.add(key)
                putBundle("entry$index", Bundle().apply {
                    putBoolean("keyed", value.keyed); putBoolean("focus", value.focused)
                    putInt("start", if (value.sensitive) -1 else value.start); putInt("end", if (value.sensitive) -1 else value.end)
                    putBoolean("sensitive", value.sensitive)
                    putInt("child_index", value.childFocus.index); putString("child_signature", value.childFocus.signature)
                    putFloat("x", value.scrollX); putFloat("y", value.scrollY)
                })
            }
            putStringArrayList("keys", keys)
        }
    }
    fun fromBundle(bundle: Bundle?): ViewStatePolicy.Snapshot? {
        main()
        return try { decode(bundle) } catch (_: RuntimeException) { null }
    }
    internal fun encodedSize(bundle: Bundle): Int {
        main()
        val parcel = Parcel.obtain()
        return try { parcel.writeBundle(bundle); parcel.dataSize() } finally { parcel.recycle() }
    }
    // Typed Bundle getters can log a mismatched value before returning a
    // default. Inspect types directly without including saved values in logs.
    @Suppress("DEPRECATION")
    internal fun raw(bundle: Bundle?, key: String): Any? = try { bundle?.get(key) } catch (_: RuntimeException) { null }
    private fun decode(bundle: Bundle?): ViewStatePolicy.Snapshot? {
        if (bundle == null || raw(bundle, "version") != 1 || encodedSize(bundle) > MAX_SAVED_BYTES) return null
        val route = raw(bundle, "route") as? String ?: return null
        val shape = raw(bundle, "shape") as? String ?: return null
        val screen = raw(bundle, "screen") as? String ?: return null
        val rawKeys = raw(bundle, "keys") as? ArrayList<*> ?: return null
        if (rawKeys.size > ViewStatePolicy.MAX_ENTRIES) return null
        val keys = rawKeys.map { it as? String ?: return null }
        if (route.toByteArray(Charsets.UTF_8).size > 4096 || !shape.matches(Regex("[0-9a-f]{64}")) || !screen.matches(Regex("[0-9a-f]{64}")) || keys.size > ViewStatePolicy.MAX_ENTRIES || keys.distinct().size != keys.size || keys.sumOf { it.toByteArray(Charsets.UTF_8).size } > 32_768) return null
        val entries = linkedMapOf<String, ViewStatePolicy.Value>()
        for ((index, key) in keys.withIndex()) {
            val item = raw(bundle, "entry$index") as? Bundle ?: return null
            // Older v1 bundles lack both optional fields. A partial or mistyped
            // extension is malformed, not an invitation to guess another child.
            val child = if (!item.containsKey("child_index") && !item.containsKey("child_signature")) CompoundFocusPolicy.Locator()
                else CompoundFocusPolicy.Locator(raw(item, "child_index") as? Int ?: return null,
                    raw(item, "child_signature") as? String ?: return null)
            val value = ViewStatePolicy.Value(raw(item, "keyed") as? Boolean ?: return null,
                raw(item, "focus") as? Boolean ?: return null,
                raw(item, "start") as? Int ?: return null, raw(item, "end") as? Int ?: return null,
                raw(item, "x") as? Float ?: return null, raw(item, "y") as? Float ?: return null,
                raw(item, "sensitive") as? Boolean ?: return null, child)
            if (!value.valid()) return null
            entries[key] = value
        }
        val x = raw(bundle, "x") as? Float ?: return null
        val y = raw(bundle, "y") as? Float ?: return null
        if (!x.isFinite() || !y.isFinite() || x !in 0f..1_000_000f || y !in 0f..1_000_000f) return null
        return ViewStatePolicy.Snapshot(route, shape, entries, raw(bundle, "ime") as? Boolean ?: return null, x, y, screen)
    }
}
