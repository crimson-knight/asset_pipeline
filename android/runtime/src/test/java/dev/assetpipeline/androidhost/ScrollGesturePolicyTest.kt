package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class ScrollGesturePolicyTest {
    @Test fun aViewportThatCannotMoveNeverClaimsTheGesture() {
        assertFalse(ScrollGesturePolicy.claimsOnDown(canScrollForward = false, canScrollBackward = false))
        assertTrue(ScrollGesturePolicy.claimsOnDown(canScrollForward = true, canScrollBackward = false))
        assertTrue(ScrollGesturePolicy.claimsOnDown(canScrollForward = false, canScrollBackward = true))
    }
    @Test fun travelInsideTheSlopStaysUndecided() {
        for (delta in listOf(0f, 8f, -8f, 24f, -24f))
            assertEquals(ScrollGesturePolicy.Claim.UNDECIDED, ScrollGesturePolicy.onMove(delta, 24, true, true))
    }
    @Test fun keepsWhileContentCanFollowTheFingerAndYieldsAtTheEdge() {
        // Finger up (negative travel) scrolls forward.
        assertEquals(ScrollGesturePolicy.Claim.KEEP, ScrollGesturePolicy.onMove(-25f, 24, canScrollForward = true, canScrollBackward = false))
        assertEquals(ScrollGesturePolicy.Claim.YIELD, ScrollGesturePolicy.onMove(-25f, 24, canScrollForward = false, canScrollBackward = true))
        // Finger down (positive travel) scrolls backward.
        assertEquals(ScrollGesturePolicy.Claim.KEEP, ScrollGesturePolicy.onMove(25f, 24, canScrollForward = false, canScrollBackward = true))
        assertEquals(ScrollGesturePolicy.Claim.YIELD, ScrollGesturePolicy.onMove(25f, 24, canScrollForward = true, canScrollBackward = false))
    }
    @Test fun invalidTravelOrSlopIsRejected() {
        assertThrows(IllegalArgumentException::class.java) { ScrollGesturePolicy.onMove(Float.NaN, 24, true, true) }
        assertThrows(IllegalArgumentException::class.java) { ScrollGesturePolicy.onMove(1f, -1, true, true) }
    }
}
