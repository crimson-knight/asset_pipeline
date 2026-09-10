package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class CompoundFocusPolicyTest {
    @Test fun ordinalMatchesOnlyTheSameOrderedOptionCatalog() {
        val values = listOf("One", "Two 雪", "Three\u0000😀")
        val locator = CompoundFocusPolicy.Locator(1, requireNotNull(CompoundFocusPolicy.signature(values)))
        assertTrue(CompoundFocusPolicy.matches(locator, values))
        assertFalse(CompoundFocusPolicy.matches(locator, values.reversed()))
        assertFalse(CompoundFocusPolicy.matches(locator, listOf("One", "Replacement", "Three\u0000😀")))
        assertFalse(CompoundFocusPolicy.matches(locator, values.take(1)))
        assertNotEquals(CompoundFocusPolicy.signature(listOf("a", "bc")), CompoundFocusPolicy.signature(listOf("ab", "c")))
    }
    @Test fun limitsAndMalformedLocatorsCannotSelectAnotherChild() {
        assertNull(CompoundFocusPolicy.signature(emptyList()))
        assertNull(CompoundFocusPolicy.signature(List(257) { "a" }))
        assertNull(CompoundFocusPolicy.signature(listOf("a".repeat(4097))))
        assertNull(CompoundFocusPolicy.signature(List(4) { "雪".repeat(4096) }))
        assertTrue(CompoundFocusPolicy.Locator().valid())
        assertFalse(CompoundFocusPolicy.Locator(0, "").valid())
        assertFalse(CompoundFocusPolicy.Locator(-1, "a".repeat(64)).valid())
        assertFalse(CompoundFocusPolicy.Locator(256, "a".repeat(64)).valid())
        assertFalse(CompoundFocusPolicy.Locator(0, "private-invalid").valid())
        assertFalse(CompoundFocusPolicy.matches(CompoundFocusPolicy.Locator(), listOf("One")))
    }
    @Test fun snapshotStoresOnlyAValueLocatorAndRejectsAnUnfocusedChildClaim() {
        val names = listOf("Choice one", "Choice two")
        val locator = CompoundFocusPolicy.Locator(0, requireNotNull(CompoundFocusPolicy.signature(names)))
        assertFalse(locator.signature.contains("Choice"))
        val value = ViewStatePolicy.Value(true, true, -1, -1, 0f, 0f, childFocus = locator)
        assertTrue(value.valid())
        assertFalse(value.copy(focused = false).valid())
        assertFalse(value.copy(childFocus = locator.copy(index = -2)).valid())
    }
}
