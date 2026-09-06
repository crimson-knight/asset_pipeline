package dev.assetpipeline.androidhost

import kotlin.math.roundToInt

/** Pure measurement data; -1 is the native wire sentinel for unspecified. */
object LayoutPolicy {
    const val UNSPECIFIED = -1f
    const val MAX_DP = 1_000_000f
    data class Axis(val minimum: Float = UNSPECIFIED, val maximum: Float = UNSPECIFIED) {
        init {
            for (value in listOf(minimum, maximum)) require(value == UNSPECIFIED || value.isFinite() && value in 0f..MAX_DP) {
                "Layout dimensions must be finite nonnegative dp or unspecified"
            }
            require(minimum < 0 || maximum < 0 || minimum <= maximum) { "Layout minimum exceeds maximum" }
        }
        val fixed: Boolean get() = minimum >= 0 && minimum == maximum
        val needsBounds: Boolean get() = maximum >= 0 && !fixed
    }
    data class Bounds(val width: Axis, val height: Axis, val fillHorizontal: Boolean, val fillVertical: Boolean) {
        val needsBounds: Boolean get() = width.needsBounds || height.needsBounds
    }
    fun pixels(dp: Float, density: Float): Int {
        require(dp.isFinite() && dp in 0f..MAX_DP && density.isFinite() && density > 0f)
        val pixels = dp.toDouble() * density
        require(pixels <= 0x3fffffff) { "Layout dimension exceeds Android measure capacity" }
        return pixels.roundToInt()
    }
}
