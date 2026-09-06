package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class SemanticsPolicyTest {
    private fun base() = SemanticsPolicy.Metadata(null, null, null, "button", false, null, "automation-only", null, true, false, null, emptyList(), emptyList(), null)
    private fun invalid(value: SemanticsPolicy.Metadata) {
        try { SemanticsPolicy.validate(value); fail("Invalid metadata accepted") } catch (expected: IllegalArgumentException) { assertFalse(expected.message!!.contains("private")) }
    }
    @Test fun explicitOptOutWinsOverDefaultsRequestsAndActions() {
        assertTrue(base().keyboardFocusable)
        assertFalse(base().copy(focusable = false, focused = true, actions = listOf(SemanticsPolicy.Action("Action", 1))).keyboardFocusable)
        assertTrue(base().copy(defaultFocusable = false, focused = true).keyboardFocusable)
        assertTrue(base().copy(defaultFocusable = false, actions = listOf(SemanticsPolicy.Action("Action", 1))).keyboardFocusable)
        assertFalse(base().copy(defaultFocusable = false).keyboardFocusable)
    }
    @Test fun traitsAndRolesAreIndependentOfIdentifiers() {
        assertNull(base().label)
        assertEquals("automation-only", base().testId)
        assertTrue(base().copy(traits = listOf("selected", "not_enabled", "header")).let { it.selected && it.disabled && it.heading })
        assertTrue(base().copy(role = "header").heading)
        assertFalse(base().heading)
    }
    @Test fun actionLimitTokensNamesAndUniqueOwnershipAreChecked() {
        SemanticsPolicy.validate(base().copy(actions = (1L..16L).map { SemanticsPolicy.Action("Action $it", it) }))
        invalid(base().copy(actions = (1L..17L).map { SemanticsPolicy.Action("Action $it", it) }))
        for (name in listOf("", " ", "雪".repeat(86))) invalid(base().copy(actions = listOf(SemanticsPolicy.Action(name, 1))))
        for (token in listOf(0L, -1L)) invalid(base().copy(actions = listOf(SemanticsPolicy.Action("Action", token))))
        invalid(base().copy(actions = listOf(SemanticsPolicy.Action("One", 1), SemanticsPolicy.Action("Two", 1))))
    }
    @Test fun utf8MetadataBoundsDoNotLeakInput() {
        SemanticsPolicy.validate(base().copy(label = "a".repeat(4096), identifier = "a".repeat(1024)))
        invalid(base().copy(label = "private" + "雪".repeat(1366)))
        invalid(base().copy(hint = "a".repeat(2049)))
        invalid(base().copy(value = "a".repeat(2049)))
        invalid(base().copy(identifier = "a".repeat(1025)))
        invalid(base().copy(testId = "a".repeat(1025)))
    }
    @Test fun shortcutShapeAndModifiersAreBounded() {
        SemanticsPolicy.validate(base().copy(shortcut = SemanticsPolicy.Shortcut("return", listOf("control", "shift"))))
        SemanticsPolicy.validate(base().copy(shortcut = SemanticsPolicy.Shortcut("p", emptyList())))
        for (key in listOf("", "a".repeat(33))) invalid(base().copy(shortcut = SemanticsPolicy.Shortcut(key, emptyList())))
        invalid(base().copy(shortcut = SemanticsPolicy.Shortcut("p", listOf("private-invalid-modifier"))))
        invalid(base().copy(shortcut = SemanticsPolicy.Shortcut("p", List(9) { "shift" })))
    }
    @Test fun rolesAndTraitsHaveBoundedForwardCompatibleMetadata() {
        SemanticsPolicy.validate(base().copy(role = "future-role", traits = listOf("future-trait")))
        invalid(base().copy(role = "a".repeat(129)))
        invalid(base().copy(traits = List(33) { "selected" }))
        invalid(base().copy(traits = listOf("a".repeat(129))))
        assertEquals("android.widget.EditText", SemanticsPolicy.classes["text_field"])
        assertEquals("android.widget.SeekBar", SemanticsPolicy.classes["slider"])
    }
}
