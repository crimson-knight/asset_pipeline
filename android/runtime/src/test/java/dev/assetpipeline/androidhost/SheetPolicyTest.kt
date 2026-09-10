package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class SheetPolicyTest {
    private fun value() = SheetPolicy.Descriptor("Edit 雪 😀", listOf(0, 1, 2), 1, true, false, 1, 2)
    @Test fun onlyExplicitDetentsAndDistinctCallbacksAreAccepted() {
        assertEquals(value(), SheetPolicy.validate(value()))
        for (bad in listOf(value().copy(detents = emptyList()), value().copy(detents = listOf(1, 1)),
            value().copy(detents = listOf(3)), value().copy(selected = 3), value().copy(detents = listOf(2)),
            value().copy(title = " "), value().copy(title = "雪".repeat(1366)), value().copy(changed = 1),
            value().copy(lifecycle = 0))) assertThrows(IllegalArgumentException::class.java) { SheetPolicy.validate(bad) }
    }
    @Test fun unavailableSettledHeightsMapToTheNearestAllowedHeight() {
        assertEquals(2, SheetPolicy.nearest(1, listOf(0, 2)))
        assertEquals(1, SheetPolicy.nearest(0, listOf(1, 2)))
        assertEquals(0, SheetPolicy.nearest(2, listOf(0)))
        assertEquals(1, SheetPolicy.nearest(1, listOf(2, 1)))
    }
    @Test fun identityIsBoundedAndFramedAcrossRouteAndDeclaration() {
        assertEquals(SheetPolicy.identity("a", "bc"), SheetPolicy.identity("a", "bc"))
        assertNotEquals(SheetPolicy.identity("a", "bc"), SheetPolicy.identity("ab", "c"))
        assertEquals(70, SheetPolicy.identity("route", "key").length)
        assertThrows(IllegalArgumentException::class.java) { SheetPolicy.identity("x".repeat(4097), "key") }
    }
    @Test fun allDeclaredSetsMapOnlyToTheirNativeEndpoints() {
        for (mask in 1..7) {
            val allowed = (0..2).filter { mask and (1 shl it) != 0 }.reversed()
            for (value in allowed) assertEquals(value, SheetPolicy.value(SheetPolicy.position(value, allowed), allowed))
            if (allowed.size < 3) assertFalse(allowed.any { SheetPolicy.position(it, allowed) == SheetPolicy.Position.HALF })
        }
        assertEquals(SheetPolicy.Position.EXPANDED, SheetPolicy.position(0, listOf(0)))
        assertEquals(SheetPolicy.Position.COLLAPSED, SheetPolicy.position(1, listOf(1, 2)))
    }
    @Test fun compactSheetsRiseAboveTheKeyboardWithoutLosingTheirContentHeight() {
        for (allowed in listOf(listOf(0), listOf(1), listOf(0, 1))) {
            val hidden = SheetPolicy.geometry(2400, 63, 63, 0, allowed)
            val visible = SheetPolicy.geometry(2400, 63, 63, 883, allowed)
            assertEquals(hidden.maximumHeight - hidden.bottomInset, visible.maximumHeight - visible.bottomInset)
            assertEquals(hidden.peekHeight - hidden.bottomInset, visible.peekHeight - visible.bottomInset)
        }
        val full = SheetPolicy.geometry(2400, 63, 63, 883, listOf(0, 1, 2))
        assertEquals(2337, full.maximumHeight)
        assertEquals(1420, full.peekHeight)
        assertEquals(2020f / 2400, full.halfRatio, 0.0001f)
    }
    @Test fun viewportMeasurementsFollowTheVisiblePartOfTheDraggingSheet() {
        assertEquals(2337, SheetPolicy.viewportHeight(2400, 63, 2337))
        assertEquals(1200, SheetPolicy.viewportHeight(2400, 1200, 2337))
        assertEquals(600, SheetPolicy.viewportHeight(2400, 1800, 600))
        assertEquals(100, SheetPolicy.viewportHeight(2400, 2300, 2337))
        assertEquals(0, SheetPolicy.viewportHeight(2400, 2500, 2337))
    }
    @Test fun geometryIsBoundedForSmallWindowsAndLargeInsets() {
        for (height in listOf(1, 17, 1080, 2400, Int.MAX_VALUE)) {
            val value = SheetPolicy.geometry(height, 100, 300, Int.MAX_VALUE, listOf(0, 1, 2))
            assertTrue(value.maximumHeight in 1..height)
            assertTrue(value.peekHeight in 1..value.maximumHeight)
            assertTrue(value.halfRatio > 0 && value.halfRatio < 1)
        }
        assertThrows(IllegalArgumentException::class.java) { SheetPolicy.geometry(0, 0, 0, 0, listOf(0)) }
        assertThrows(IllegalArgumentException::class.java) { SheetPolicy.geometry(1080, -1, 0, 0, listOf(0)) }
        assertThrows(IllegalArgumentException::class.java) { SheetPolicy.geometry(1080, 0, 0, 0, listOf(0, 0)) }
    }
    @Test fun nominalCompactHeightsGrowToFitMeasuredControlsWithoutExceedingTheWindow() {
        val body = 126 + 153 // native handle plus complete control, in pixels
        val compact = SheetPolicy.geometry(1080, 63, 63, 0, listOf(0), body)
        assertEquals(342, compact.maximumHeight)
        assertEquals(153, compact.maximumHeight - compact.bottomInset - 126)
        val keyboard = SheetPolicy.geometry(1080, 63, 63, 600, listOf(0), body)
        assertEquals(879, keyboard.maximumHeight)
        assertEquals(153, keyboard.maximumHeight - keyboard.bottomInset - 126)
        val crowded = SheetPolicy.geometry(1080, 63, 63, 900, listOf(0), body)
        assertEquals(1017, crowded.maximumHeight)
        assertEquals(SheetPolicy.geometry(2400, 63, 63, 0, listOf(0)),
            SheetPolicy.geometry(2400, 63, 63, 0, listOf(0), body))
        assertEquals(1017, SheetPolicy.geometry(1080, 63, 63, 0, listOf(0, 1), Int.MAX_VALUE).maximumHeight)
        assertThrows(IllegalArgumentException::class.java) { SheetPolicy.geometry(1080, 0, 0, 0, listOf(0), -1) }
    }
    @Test fun keyboardMayTemporarilyHideChromeButNeverShrinksItsNativeTouchArea() {
        assertTrue(SheetPolicy.keepsHandle(331, 153, 126, true))
        assertFalse(SheetPolicy.keepsHandle(331, 266, 126, true))
        assertTrue(SheetPolicy.keepsHandle(392, 266, 126, true))
        assertTrue(SheetPolicy.keepsHandle(0, 266, 126, false))
        assertFalse(SheetPolicy.keepsHandle(Int.MAX_VALUE, Int.MAX_VALUE, Int.MAX_VALUE, true))
        assertThrows(IllegalArgumentException::class.java) { SheetPolicy.keepsHandle(-1, 0, 0, true) }
    }
}
