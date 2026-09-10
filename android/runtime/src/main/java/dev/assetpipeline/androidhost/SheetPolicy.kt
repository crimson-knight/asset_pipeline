package dev.assetpipeline.androidhost

import java.security.MessageDigest

/** Stable, value-only mapping. 0=small, 1=medium, 2=large. */
object SheetPolicy {
    enum class Position { COLLAPSED, HALF, EXPANDED }
    data class Geometry(val maximumHeight: Int, val peekHeight: Int, val halfRatio: Float,
        val expandedTop: Int, val bottomInset: Int)
    data class Descriptor(val title: String, val detents: List<Int>, val selected: Int,
        val drag: Boolean, val locked: Boolean, val lifecycle: Long, val changed: Long)
    fun validate(value: Descriptor): Descriptor {
        require(value.title.isNotBlank() && value.title.toByteArray(Charsets.UTF_8).size <= 4096)
        require(value.detents.size in 1..3 && value.detents.distinct().size == value.detents.size &&
            value.detents.all { it in 0..2 } && value.selected in value.detents)
        require(value.lifecycle > 0 && value.changed > 0 && value.lifecycle != value.changed)
        return value
    }
    fun nearest(value: Int, allowed: List<Int>): Int {
        require(value in 0..2 && allowed.isNotEmpty() && allowed.all { it in 0..2 })
        return allowed.minWith(compareBy<Int> { kotlin.math.abs(it - value) }.thenByDescending { it })
    }
    fun position(value: Int, allowed: List<Int>): Position {
        require(value in allowed && allowed.size in 1..3 && allowed.all { it in 0..2 })
        if (allowed.size < 3) return if (value == allowed.max()) Position.EXPANDED else Position.COLLAPSED
        return when (value) { 0 -> Position.COLLAPSED; 1 -> Position.HALF; else -> Position.EXPANDED }
    }
    fun value(position: Position, allowed: List<Int>): Int {
        require(allowed.isNotEmpty() && allowed.all { it in 0..2 })
        return when (position) {
            Position.COLLAPSED -> allowed.min()
            Position.EXPANDED -> allowed.max()
            Position.HALF -> nearest(1, allowed)
        }
    }
    /** Window-relative pixels, including the navigation/IME area once. A compact
     * sheet rises above the IME without changing its logical selected detent.
     */
    fun geometry(height: Int, topInset: Int, navigationBottom: Int, imeBottom: Int, allowed: List<Int>, minimumBody: Int = 0): Geometry {
        require(height > 0 && topInset >= 0 && navigationBottom >= 0 && imeBottom >= 0 && minimumBody >= 0)
        require(allowed.size in 1..3 && allowed.distinct().size == allowed.size && allowed.all { it in 0..2 })
        val top = topInset.coerceAtMost(height - 1)
        val maximum = height - top
        val navigation = navigationBottom.coerceAtMost(maximum)
        val bottom = maxOf(navigation, imeBottom.coerceAtMost(maximum))
        val lift = bottom - navigation
        val minimum = (bottom.toLong() + minimumBody).coerceIn(1, maximum.toLong())
        fun frame(detent: Int): Int = when (detent) {
            0 -> (height.toLong() / 4 + lift).coerceIn(minimum, maximum.toLong()).toInt()
            1 -> (height.toLong() / 2 + lift).coerceIn(minimum, maximum.toLong()).toInt()
            else -> maximum
        }
        return Geometry(frame(allowed.max()), frame(allowed.min()),
            (frame(1).toFloat() / height).coerceIn(0.0001f, 0.9999f), top, bottom)
    }
    fun viewportHeight(parentHeight: Int, sheetTop: Int, sheetHeight: Int): Int {
        require(parentHeight >= 0 && sheetHeight >= 0)
        return (parentHeight.toLong() - sheetTop).coerceIn(0, sheetHeight.toLong()).toInt()
    }
    fun keepsHandle(availableBody: Int, minimumViewport: Int, handleHeight: Int, keyboardVisible: Boolean): Boolean {
        require(availableBody >= 0 && minimumViewport >= 0 && handleHeight >= 0)
        return !keyboardVisible || minimumViewport.toLong() + handleHeight <= availableBody
    }
    fun identity(route: String, address: String): String {
        require(route.toByteArray(Charsets.UTF_8).size <= 4096 && address.toByteArray(Charsets.UTF_8).size <= 8192)
        val framed = "${route.length}:$route${address.length}:$address"
        return "sheet:" + MessageDigest.getInstance("SHA-256").digest(framed.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }
}
