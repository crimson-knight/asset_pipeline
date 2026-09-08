package dev.assetpipeline.androidhost

import kotlin.math.min

/** Pure viewport arithmetic: pixels and window geometry in, the dp report
 * Crystal receives out. The report is the container's frame less the bars the
 * host's own padding already keeps clear, with the rest of the bar overlap as
 * insets, so a padded host reports zero insets, an edge-to-edge host reports
 * the bars, and keyboard padding beyond the bars changes nothing. */
object ViewportPolicy {
    /** One amount per edge, in pixels: a bar thickness, a padding, an overlap. */
    data class Edges(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        init { require(left >= 0 && top >= 0 && right >= 0 && bottom >= 0) { "Edge amounts must not be negative" } }
        companion object { val NONE = Edges(0, 0, 0, 0) }
    }

    /** A view's frame in window coordinates, pixels. */
    data class Frame(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        init { require(right >= left && bottom >= top) { "Frame must not be inverted" } }
        val width: Int get() = right - left
        val height: Int get() = bottom - top
    }

    data class Report(val widthDp: Double, val heightDp: Double, val topDp: Double, val bottomDp: Double,
        val leftDp: Double, val rightDp: Double, val density: Double)

    /** How much of each system bar lies inside the frame. */
    fun overlap(frame: Frame, windowWidth: Int, windowHeight: Int, bars: Edges): Edges {
        require(windowWidth > 0 && windowHeight > 0) { "Window must have an area" }
        return Edges(
            left = (bars.left - frame.left).coerceIn(0, frame.width),
            top = (bars.top - frame.top).coerceIn(0, frame.height),
            right = (frame.right - (windowWidth - bars.right)).coerceIn(0, frame.width),
            bottom = (frame.bottom - (windowHeight - bars.bottom)).coerceIn(0, frame.height))
    }

    /** The report for a container whose padding keeps part of the bars clear.
     * A laid-out mount width, when there is one, is the width the tree gets. */
    fun report(frame: Frame, windowWidth: Int, windowHeight: Int, bars: Edges, padding: Edges,
        mountWidth: Int, density: Float): Report {
        require(density.isFinite() && density > 0f) { "Density must be positive" }
        require(mountWidth >= 0) { "Mount width must not be negative" }
        val inside = overlap(frame, windowWidth, windowHeight, bars)
        val kept = Edges(min(inside.left, padding.left), min(inside.top, padding.top),
            min(inside.right, padding.right), min(inside.bottom, padding.bottom))
        val width = if (mountWidth > 0) mountWidth else frame.width - kept.left - kept.right
        val height = frame.height - kept.top - kept.bottom
        require(width > 0 && height > 0) { "Viewport has no area" }
        fun dp(pixels: Int) = pixels / density.toDouble()
        return Report(dp(width), dp(height), dp(inside.top - kept.top), dp(inside.bottom - kept.bottom),
            dp(inside.left - kept.left), dp(inside.right - kept.right), density.toDouble())
    }
}
