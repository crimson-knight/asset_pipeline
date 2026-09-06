package dev.assetpipeline.androidhost

/** Value-only policy, independently testable without a View or Context. */
object SemanticsPolicy {
    const val MAX_ACTIONS = 16
    const val MAX_PACKET_BYTES = 32_768
    data class Action(val name: String, val token: Long)
    data class Shortcut(val key: String, val modifiers: List<String>)
    data class Metadata(val label: String?, val hint: String?, val value: String?, val role: String?,
        val explicitRole: Boolean, val identifier: String?, val testId: String?, val focusable: Boolean?,
        val defaultFocusable: Boolean, val focused: Boolean, val tabIndex: Int?, val traits: List<String>,
        val actions: List<Action>, val shortcut: Shortcut?) {
        val disabled get() = "not_enabled" in traits
        val selected get() = "selected" in traits
        val heading get() = role == "header" || "header" in traits
        val keyboardFocusable get() = focusable ?: (defaultFocusable || focused || actions.isNotEmpty())
    }
    val roles = setOf("button", "link", "text", "header", "image", "text_field", "search", "checkbox",
        "radio", "radio_group", "switch", "slider", "progress_bar", "tab", "tab_list", "tab_panel",
        "list", "list_item", "dialog", "alert", "menu", "menu_item", "none", "combobox", "group")
    val classes = mapOf("button" to "android.widget.Button", "link" to "android.widget.Button",
        "text" to "android.widget.TextView", "header" to "android.widget.TextView",
        "image" to "android.widget.ImageView", "text_field" to "android.widget.EditText",
        "search" to "android.widget.EditText", "checkbox" to "android.widget.CheckBox",
        "radio" to "android.widget.RadioButton", "radio_group" to "android.widget.RadioGroup",
        "switch" to "android.widget.Switch", "slider" to "android.widget.SeekBar",
        "progress_bar" to "android.widget.ProgressBar", "list" to "android.widget.ListView",
        "combobox" to "android.widget.Spinner")
    fun validate(value: Metadata): Metadata {
        fun bounded(text: String?, bytes: Int) = text == null || text.toByteArray(Charsets.UTF_8).size <= bytes
        require(bounded(value.label, 4096) && bounded(value.hint, 2048) && bounded(value.value, 2048) &&
            bounded(value.role, 128) && bounded(value.identifier, 1024) && bounded(value.testId, 1024)) { "Native accessibility text exceeds its limit" }
        require(value.traits.size <= 32 && value.traits.all { bounded(it, 128) }) { "Native accessibility traits exceed their limit" }
        require(value.actions.size <= MAX_ACTIONS && value.actions.all { it.name.isNotBlank() && bounded(it.name, 256) && it.token > 0 } &&
            value.actions.map { it.token }.distinct().size == value.actions.size) { "Invalid native accessibility actions" }
        value.shortcut?.let { shortcut ->
            require(shortcut.key.isNotEmpty() && bounded(shortcut.key, 32) && shortcut.modifiers.size <= 8 &&
                shortcut.modifiers.all { it in setOf("control", "command", "alt", "option", "shift") }) { "Invalid native keyboard shortcut" }
        }
        return value
    }
}
