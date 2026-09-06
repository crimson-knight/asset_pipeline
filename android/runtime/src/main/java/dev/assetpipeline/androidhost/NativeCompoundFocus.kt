package dev.assetpipeline.androidhost

import android.view.View
import android.widget.RadioButton
import android.widget.RadioGroup

/** Only modeled native compounds participate; arbitrary descendants do not. */
object NativeCompoundFocus {
    private fun options(group: RadioGroup): List<String>? {
        if (group.childCount !in 1..CompoundFocusPolicy.MAX_OPTIONS) return null
        return (0 until group.childCount).map { (group.getChildAt(it) as? RadioButton)?.text?.toString() ?: return null }
    }
    fun target(owner: View): View {
        val base = NativeSemantics.target(owner)
        if (base !is RadioGroup) return base
        val children = (0 until base.childCount).map { base.getChildAt(it) }
        return children.firstOrNull { it.isFocused }
            ?: children.firstOrNull { it.id == base.checkedRadioButtonId && it.isEnabled && it.isFocusable }
            ?: children.firstOrNull { it.isEnabled && it.isFocusable } ?: base
    }
    fun capture(owner: View): CompoundFocusPolicy.Locator {
        val base = NativeSemantics.target(owner) as? RadioGroup ?: return CompoundFocusPolicy.Locator()
        val index = (0 until base.childCount).firstOrNull { base.getChildAt(it).isFocused } ?: return CompoundFocusPolicy.Locator()
        val values = options(base) ?: return CompoundFocusPolicy.Locator()
        val signature = CompoundFocusPolicy.signature(values) ?: return CompoundFocusPolicy.Locator()
        return CompoundFocusPolicy.Locator(index, signature)
    }
    fun restore(owner: View, locator: CompoundFocusPolicy.Locator): Boolean {
        if (!locator.present) return NativeSemantics.requestFocus(target(owner))
        val group = NativeSemantics.target(owner) as? RadioGroup ?: return false
        val values = options(group) ?: return false
        if (!CompoundFocusPolicy.matches(locator, values)) return false
        return NativeSemantics.requestFocus(group.getChildAt(locator.index))
    }
}
