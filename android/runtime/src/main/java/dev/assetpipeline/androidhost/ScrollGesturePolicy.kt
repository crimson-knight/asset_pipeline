package dev.assetpipeline.androidhost

import kotlin.math.abs

/**
 * Which nested viewport owns a vertical drag.
 *
 * Stock Android lets a child ScrollView scroll before its parent. Samsung's
 * One UI hands the parent the drag first, which left an inner two-axis
 * viewport unscrollable on a Galaxy A15 5G (Android 16) while the emulators
 * scrolled it. The viewport claims the gesture while it can consume it and
 * yields at an edge, so a page still scrolls past a viewport at its end.
 * Pure decisions; the view applies them.
 */
object ScrollGesturePolicy {
    enum class Claim { KEEP, YIELD, UNDECIDED }

    /** On touch down: claim only when the viewport can move at all. */
    fun claimsOnDown(canScrollForward: Boolean, canScrollBackward: Boolean): Boolean =
        canScrollForward || canScrollBackward

    /**
     * On move: undecided inside the touch slop; then keep while the content
     * can move in the finger's direction, else yield. [deltaY] is the finger's
     * travel since touch down (negative upward); a finger moving up reveals
     * content below, which is scrolling forward.
     */
    fun onMove(deltaY: Float, touchSlop: Int, canScrollForward: Boolean, canScrollBackward: Boolean): Claim {
        require(touchSlop >= 0 && deltaY.isFinite()) { "Gesture travel must be finite and the slop nonnegative" }
        if (abs(deltaY) <= touchSlop) return Claim.UNDECIDED
        val consumes = if (deltaY < 0f) canScrollForward else canScrollBackward
        return if (consumes) Claim.KEEP else Claim.YIELD
    }
}
