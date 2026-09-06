package dev.assetpipeline.androidhost

import android.os.Bundle
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.SearchView
import android.widget.Spinner
import android.widget.RadioGroup
import androidx.core.view.AccessibilityDelegateCompat
import androidx.core.view.ViewCompat
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat
import com.google.android.material.textfield.TextInputLayout
import org.json.JSONArray
import org.json.JSONObject

/** Per-View metadata. No global Activity/View registry or saved application values. */
object NativeSemantics {
    private fun main() = check(Looper.myLooper() == Looper.getMainLooper()) { "Native semantics require the main looper" }
    private fun resource(view: View, name: String) = view.resources.getIdentifier(name, "id", view.context.packageName).also {
        check(it != 0) { "Host must include canonical Android runtime resources" }
    }
    fun metadata(view: View): SemanticsPolicy.Metadata? = view.getTag(resource(view, "ap_native_semantics")) as? SemanticsPolicy.Metadata
    fun testId(view: View): String? = metadata(view)?.testId
    fun identifier(view: View): String? = metadata(view)?.let { it.identifier ?: it.testId }
    fun target(view: View): View {
        if (view is TextInputLayout) return view.editText ?: view
        if (view is SearchView || (view is ViewGroup && metadata(view)?.role == "combobox")) {
            val pending = java.util.ArrayDeque<View>()
            pending.add(view)
            var visited = 0
            while (pending.isNotEmpty() && visited++ < 64) {
                val child = pending.removeFirst()
                if (view is SearchView && child is EditText) return child
                if (child is Spinner) return child
                if (child is ViewGroup) for (index in 0 until child.childCount) pending.add(child.getChildAt(index))
            }
        }
        return view
    }
    private fun nullableString(json: JSONObject, key: String): String? = when (val value = json.get(key)) {
        JSONObject.NULL -> null
        is String -> value
        else -> throw IllegalArgumentException("Invalid native semantics field type")
    }
    private fun strings(array: JSONArray): List<String> = (0 until array.length()).map { array.get(it) as? String ?: error("Invalid native semantics list") }
    private fun decode(packet: String): SemanticsPolicy.Metadata {
        require(packet.toByteArray(Charsets.UTF_8).size <= SemanticsPolicy.MAX_PACKET_BYTES) { "Native semantics packet exceeds its limit" }
        return try {
            val json = JSONObject(packet)
            require(json.get("version") == 1)
            val actions = json.getJSONArray("actions")
            require(actions.length() <= SemanticsPolicy.MAX_ACTIONS)
            val shortcut = json.get("shortcut").let { if (it === JSONObject.NULL) null else (it as JSONObject).let { obj ->
                SemanticsPolicy.Shortcut(obj.get("key") as String, strings(obj.getJSONArray("modifiers")))
            } }
            SemanticsPolicy.validate(SemanticsPolicy.Metadata(nullableString(json, "label"), nullableString(json, "hint"),
                nullableString(json, "value"), nullableString(json, "role"), json.get("explicit_role") as Boolean,
                nullableString(json, "identifier"), nullableString(json, "test_id"),
                json.get("focusable").let { if (it === JSONObject.NULL) null else it as Boolean },
                json.get("default_focusable") as Boolean, json.get("focused") as Boolean,
                json.get("tab_index").let { if (it === JSONObject.NULL) null else it as Int }, strings(json.getJSONArray("traits")),
                (0 until actions.length()).map { index -> val action = actions.getJSONObject(index)
                    val token = action.get("token")
                    require(token is Int || token is Long)
                    SemanticsPolicy.Action(action.get("name") as String, (token as Number).toLong())
                }, shortcut))
        } catch (_: Exception) {
            // JSONObject errors may embed input. Do not expose their cause/message.
            throw IllegalArgumentException("Invalid native semantics metadata")
        }
    }
    @JvmStatic fun configure(owner: View, packet: String) {
        main()
        decorate(owner, decode(packet))
    }
    internal fun dialogAction(view: View, testId: String?) {
        decorate(view, SemanticsPolicy.Metadata(null, null, null, "button", false, null, testId,
            null, true, false, null, emptyList(), emptyList(), null))
    }
    internal fun decorate(owner: View, metadata: SemanticsPolicy.Metadata) {
        main()
        val meta = SemanticsPolicy.validate(metadata)
        owner.setTag(resource(owner, "ap_native_semantics"), meta)
        val view = target(owner)
        if (owner !== view) owner.isFocusable = false
        if (meta.disabled) { owner.isEnabled = false; view.isEnabled = false }
        if (meta.selected) view.isSelected = true
        view.isFocusable = meta.keyboardFocusable
        if (view is RadioGroup) {
            // A group is not an extra keyboard stop before its actual options.
            view.isFocusable = false
            for (index in 0 until view.childCount) {
                val option = view.getChildAt(index)
                option.isFocusable = meta.keyboardFocusable
                if (!meta.keyboardFocusable) { option.isFocusableInTouchMode = false; option.clearFocus() }
                if (meta.disabled) option.isEnabled = false
            }
        }
        if (!meta.keyboardFocusable) { view.isFocusableInTouchMode = false; view.clearFocus() }
        if (meta.role == "none") view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        if (meta.heading) ViewCompat.setAccessibilityHeading(view, true)
        meta.value?.let { ViewCompat.setStateDescription(view, it) }
        // Editable text is exposed by its native delegate, with a semantic hint
        // rather than a contentDescription that obscures entered text/actions.
        if (view is EditText) {
            view.contentDescription = null
            if (owner !== view) owner.contentDescription = null
        } else if (meta.label != null) view.contentDescription = meta.label
        if (meta.role != null && meta.role !in SemanticsPolicy.roles)
            Log.w("APSemantics", "Unsupported accessibility role; native semantics retained")
        if (meta.traits.any { it !in setOf("selected", "not_enabled", "header") })
            Log.w("APSemantics", "Some accessibility traits have no Android mapping")
        val actionIds = meta.actions.indices.map { resource(owner, "ap_accessibility_action_$it") }
        // Wrap the existing platform/Material delegate. Its editable text,
        // errors, range/collection data, node provider and built-in actions stay.
        val delegate = object : AccessibilityDelegateCompat(view.accessibilityDelegate ?: View.AccessibilityDelegate()) {
            override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfoCompat) {
                super.onInitializeAccessibilityNodeInfo(host, info)
                meta.testId?.let { info.extras.putString("dev.assetpipeline.test_id", it) }
                meta.identifier?.let { info.extras.putString("dev.assetpipeline.accessibility_identifier", it) }
                meta.tabIndex?.let { info.extras.putInt("dev.assetpipeline.tab_index", it) }
                meta.role?.let { info.extras.putString("dev.assetpipeline.accessibility_role", it) }
                if (meta.explicitRole) SemanticsPolicy.classes[meta.role]?.let { info.className = it }
                if (meta.heading) info.isHeading = true
                if (meta.selected) info.isSelected = true
                if (meta.disabled) info.isEnabled = false
                meta.value?.let { info.stateDescription = it }
                meta.hint?.let { info.tooltipText = it }
                if (host is EditText && meta.label != null) {
                    info.hintText = meta.label
                    info.isShowingHintText = host.text.isEmpty()
                    if (host.text.isEmpty()) info.text = meta.label
                }
                for ((index, action) in meta.actions.withIndex())
                    info.addAction(AccessibilityNodeInfoCompat.AccessibilityActionCompat(actionIds[index], action.name))
            }
            override fun performAccessibilityAction(host: View, action: Int, args: Bundle?): Boolean {
                val index = actionIds.indexOf(action)
                if (index >= 0) {
                    if (!actionable(host)) return false
                    CrystalBridge.dispatchVoidCallback(meta.actions[index].token)
                    return true
                }
                return super.performAccessibilityAction(host, action, args)
            }
        }
        ViewCompat.setAccessibilityDelegate(view, delegate)
    }
    private fun actionable(view: View) = NativeWindowScope.allows(view) && view.isAttachedToWindow && view.isShown && view.isEnabled &&
        CrystalBridge.debugSessionState() == HostSession.State.FOREGROUND
    fun requestFocus(view: View): Boolean {
        if (!view.isShown || !view.isEnabled || !view.isFocusable) return false
        view.isFocusableInTouchMode = true
        return view.requestFocus()
    }
    fun applyFocusRequests(root: View): View? {
        main()
        for (node in NativeViewState.nodes(root)) {
            if (metadata(node.view)?.focused == true) {
                val view = NativeCompoundFocus.target(node.view)
                if (requestFocus(view)) return view
            }
        }
        return null
    }
    fun dispatchShortcut(root: View, event: KeyEvent, unmodifiedOnly: Boolean = false): Boolean {
        main()
        val nodes = try { NativeViewState.nodes(root) } catch (_: NativeViewState.BudgetExceeded) {
            Log.w("APSemantics", "View metadata limit reached; keyboard shortcuts skipped")
            return false
        }
        for (node in nodes) {
            val shortcut = metadata(node.view)?.shortcut ?: continue
            val view = target(node.view)
            if (!actionable(view)) continue
            if (unmodifiedOnly) {
                // Plain keys belong to the focused native control, never to a
                // global accelerator that could steal text from an editor.
                if (shortcut.modifiers.isNotEmpty() || !view.isFocused || view is EditText) continue
            } else if (shortcut.modifiers.isEmpty()) continue
            val name = when (shortcut.key.lowercase()) {
                "return" -> "ENTER"; "escape" -> "ESCAPE"; "space" -> "SPACE"
                "up" -> "DPAD_UP"; "down" -> "DPAD_DOWN"; "left" -> "DPAD_LEFT"; "right" -> "DPAD_RIGHT"
                "delete" -> "FORWARD_DEL"; "backspace" -> "DEL"; else -> shortcut.key.uppercase()
            }
            val code = KeyEvent.keyCodeFromString("KEYCODE_$name")
            var modifiers = 0
            for (modifier in shortcut.modifiers) modifiers = modifiers or when (modifier) {
                "control" -> KeyEvent.META_CTRL_ON; "command" -> KeyEvent.META_META_ON
                "option", "alt" -> KeyEvent.META_ALT_ON; "shift" -> KeyEvent.META_SHIFT_ON; else -> 0
            }
            if (code != KeyEvent.KEYCODE_UNKNOWN && code == event.keyCode && KeyEvent.metaStateHasModifiers(event.metaState, modifiers) && view.isClickable) {
                if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) view.performClick()
                return event.action == KeyEvent.ACTION_DOWN || event.action == KeyEvent.ACTION_UP
            }
        }
        return false
    }
}
