package dev.assetpipeline.androidhost

import android.content.Context
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import kotlin.math.max
import kotlin.math.min

class CrystalLinearLayout(context: Context) : LinearLayout(context) {
    var crystalAlignment: Int = 1
    var crystalFillEqually: Boolean = false
    var crystalSpacing: Int = 0

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        if (orientation == HORIZONTAL) {
            // Older Android places transparent dividers on the wrong side in
            // RTL, moving a requested gap to the edge of the row. Owned logical
            // margins express spacing consistently on every supported API.
            var preceding = false
            for (index in 0 until childCount) {
                val child = getChildAt(index)
                val params = child.layoutParams as LayoutParams
                params.marginStart = if (child.visibility != GONE && preceding) crystalSpacing else 0
                params.marginEnd = 0
                params.resolveLayoutDirection(layoutDirection)
                if (child.visibility != GONE) preceding = true
            }
        }
        if (!crystalFillEqually || orientation != HORIZONTAL ||
            View.MeasureSpec.getMode(widthMeasureSpec) == View.MeasureSpec.EXACTLY) {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            return
        }
        // Find the natural equal-cell width first. Weighted WRAP_CONTENT in a
        // constrained LinearLayout otherwise divides slack, not total widths.
        // The second, exact pass allocates identical zero-basis weighted slots,
        // even when AT_MOST is smaller than the natural row. Native layout
        // still owns hidden children, rounding, RTL and cross alignment.
        super.onMeasure(View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED), heightMeasureSpec)
        val width = resolveSizeAndState(measuredWidth, widthMeasureSpec, measuredState)
        super.onMeasure(View.MeasureSpec.makeMeasureSpec(width and View.MEASURED_SIZE_MASK, View.MeasureSpec.EXACTLY), heightMeasureSpec)
        setMeasuredDimension(width, measuredHeightAndState)
    }
}
class CrystalOverlayLayout(context: Context) : FrameLayout(context) { var crystalAlignment: Int = 1 }

/** Per-view layout metadata lives in owned LayoutParams, never a global map. */
object NativeLayout {
    private const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
    private const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
    private class PreparedParams(width: Int, height: Int, val bounds: LayoutPolicy.Bounds) : ViewGroup.LayoutParams(width, height)
    private fun main() = check(Looper.myLooper() == Looper.getMainLooper()) { "Native layout requires the main looper" }
    private fun dp(view: View, value: Float) = LayoutPolicy.pixels(value, view.resources.displayMetrics.density)

    @JvmStatic fun prepare(view: View, minWidth: Float, minHeight: Float, maxWidth: Float, maxHeight: Float, fillHorizontal: Boolean, fillVertical: Boolean) {
        main()
        val bounds = LayoutPolicy.Bounds(LayoutPolicy.Axis(minWidth, maxWidth), LayoutPolicy.Axis(minHeight, maxHeight), fillHorizontal, fillVertical)
        if (minWidth >= 0) view.minimumWidth = dp(view, minWidth)
        if (minHeight >= 0) view.minimumHeight = dp(view, minHeight)
        if (minWidth >= 0 || minHeight >= 0 || maxWidth >= 0 || maxHeight >= 0 || fillHorizontal || fillVertical) {
            view.layoutParams = PreparedParams(if (bounds.width.fixed) dp(view, minWidth) else WRAP,
                if (bounds.height.fixed) dp(view, minHeight) else WRAP, bounds)
        }
    }

    /** Null means no new wrapper, not an error. Widget identity stays intact. */
    @JvmStatic fun wrapPrepared(view: View): View? {
        main()
        val params = view.layoutParams as? PreparedParams ?: return null
        if (!params.bounds.needsBounds) return null
        check(view.parent == null) { "Cannot wrap an already attached native view" }
        return BoundsFrame(view.context, params.bounds).apply {
            layoutParams = params
            visibility = view.visibility
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            isSaveEnabled = false
            addView(view, FrameLayout.LayoutParams(MATCH, MATCH, Gravity.CENTER))
        }
    }

    private class BoundsFrame(context: Context, private val bounds: LayoutPolicy.Bounds) : FrameLayout(context) {
        private fun capped(spec: Int, axis: LayoutPolicy.Axis): Int {
            if (axis.maximum < 0) return spec
            val cap = dp(this, axis.maximum)
            val mode = View.MeasureSpec.getMode(spec)
            val size = View.MeasureSpec.getSize(spec)
            return View.MeasureSpec.makeMeasureSpec(if (mode == View.MeasureSpec.UNSPECIFIED) cap else min(size, cap),
                if (mode == View.MeasureSpec.UNSPECIFIED) View.MeasureSpec.AT_MOST else mode)
        }
        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            super.onMeasure(capped(widthMeasureSpec, bounds.width), capped(heightMeasureSpec, bounds.height))
            // Android's parent's exact allocation wins for the outer slot; the
            // bounded real widget remains centered within it. Never violate an
            // EXACTLY measure contract in order to simulate a CSS max-size.
            setMeasuredDimension(resolveSizeAndState(measuredWidth, widthMeasureSpec, measuredState),
                resolveSizeAndState(measuredHeight, heightMeasureSpec, measuredState shl MEASURED_HEIGHT_STATE_SHIFT))
        }
    }

    @JvmStatic fun configureStack(view: View, alignment: Int) {
        main(); require(alignment in 0..5)
        when (view) {
            is CrystalLinearLayout -> {
                view.crystalAlignment = alignment
                view.gravity = if (view.orientation == LinearLayout.VERTICAL) when (alignment) {
                    0 -> Gravity.START; 2 -> Gravity.END; 5 -> Gravity.START; else -> Gravity.CENTER_HORIZONTAL
                } or Gravity.TOP else when (alignment) {
                    3 -> Gravity.TOP; 4 -> Gravity.BOTTOM; 5 -> Gravity.TOP; else -> Gravity.CENTER_VERTICAL
                } or Gravity.START
            }
            is CrystalOverlayLayout -> view.crystalAlignment = alignment
            else -> error("Unknown native stack type")
        }
    }

    @JvmStatic fun configureEqualWidth(view: View, enabled: Boolean) {
        main()
        require(view is CrystalLinearLayout && view.orientation == LinearLayout.HORIZONTAL)
        check(view.childCount == 0) { "Configure native distribution before adding children" }
        view.crystalFillEqually = enabled
        view.isMeasureWithLargestChildEnabled = enabled
        view.isBaselineAligned = !enabled
    }

    @JvmStatic fun configureSpacing(view: View, spacing: Float) {
        main()
        require(view is CrystalLinearLayout)
        val pixels = dp(view, spacing.coerceAtLeast(0f))
        if (view.orientation == LinearLayout.HORIZONTAL) {
            view.crystalSpacing = pixels
            view.showDividers = LinearLayout.SHOW_DIVIDER_NONE
            view.dividerDrawable = null
        } else {
            view.dividerDrawable = android.graphics.drawable.GradientDrawable().apply { setSize(pixels, pixels) }
            view.showDividers = LinearLayout.SHOW_DIVIDER_MIDDLE
        }
        view.requestLayout()
    }

    private fun addEqualChild(parent: CrystalLinearLayout, child: View, fixedWidth: Int?, fixedHeight: Int?) {
        // This cell has no semantic identity, callbacks or global references.
        // A pin bounds the actual content, not its equal outer slot. Native
        // metadata traversal ignores the extra container; retired controls are
        // still the original widgets and obey their ordinary attachment checks.
        val fillHeight = parent.crystalAlignment == 5
        val cell = FrameLayout(child.context).apply {
            visibility = child.visibility
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            isSaveEnabled = false
            addView(child, FrameLayout.LayoutParams(fixedWidth ?: MATCH,
                fixedHeight ?: if (fillHeight) MATCH else WRAP, Gravity.CENTER))
        }
        parent.addView(cell, LinearLayout.LayoutParams(0,
            fixedHeight ?: if (fillHeight) MATCH else WRAP, 1f))
    }

    private fun overlayGravity(alignment: Int) = when (alignment) {
        0 -> Gravity.START or Gravity.CENTER_VERTICAL
        2 -> Gravity.END or Gravity.CENTER_VERTICAL
        3 -> Gravity.TOP or Gravity.CENTER_HORIZONTAL
        4 -> Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        5 -> Gravity.FILL
        else -> Gravity.CENTER
    }

    @JvmStatic fun addChild(parent: ViewGroup, child: View) {
        main()
        val old = child.layoutParams
        val bounds = (old as? PreparedParams)?.bounds
        val fixedWidth = old?.width?.takeIf { it >= 0 }
        val fixedHeight = old?.height?.takeIf { it >= 0 }
        when (parent) {
            is CrystalLinearLayout -> {
                val vertical = parent.orientation == LinearLayout.VERTICAL
                if (!vertical && parent.crystalFillEqually) {
                    addEqualChild(parent, child, fixedWidth, fixedHeight)
                    return
                }
                val grow = if (vertical) bounds?.fillVertical == true && fixedHeight == null
                    else bounds?.fillHorizontal == true && fixedWidth == null
                val crossFill = parent.crystalAlignment == 5 || vertical && bounds?.fillHorizontal == true
                val width = fixedWidth ?: if (vertical && crossFill) MATCH else WRAP
                val height = fixedHeight ?: if (!vertical && crossFill) MATCH else WRAP
                parent.addView(child, LinearLayout.LayoutParams(width, height, if (grow) 1f else 0f))
            }
            is CrystalOverlayLayout -> parent.addView(child, FrameLayout.LayoutParams(
                fixedWidth ?: if (parent.crystalAlignment == 5 || bounds?.fillHorizontal == true) MATCH else WRAP,
                fixedHeight ?: if (parent.crystalAlignment == 5 || bounds?.fillVertical == true) MATCH else WRAP,
                overlayGravity(parent.crystalAlignment)))
            is ScrollView -> parent.addView(child, FrameLayout.LayoutParams(fixedWidth ?: MATCH, fixedHeight ?: WRAP))
            is HorizontalScrollView -> parent.addView(child, FrameLayout.LayoutParams(fixedWidth ?: WRAP, fixedHeight ?: MATCH))
            else -> parent.addView(child)
        }
    }

    @JvmStatic fun addSpacer(parent: ViewGroup?, child: View, minimum: Float) {
        main()
        val pixels = dp(child, minimum)
        if (parent is CrystalLinearLayout && parent.crystalFillEqually && parent.orientation == LinearLayout.HORIZONTAL) {
            child.minimumWidth = max(child.minimumWidth, pixels)
            addChild(parent, child)
            return
        }
        if (parent is LinearLayout) {
            val vertical = parent.orientation == LinearLayout.VERTICAL
            val fixedAxis = child.layoutParams?.let { if (vertical) it.height else it.width }?.takeIf { it >= 0 }
            if (vertical) child.minimumHeight = max(child.minimumHeight, pixels) else child.minimumWidth = max(child.minimumWidth, pixels)
            val axis = fixedAxis ?: max(pixels, if (vertical) child.minimumHeight else child.minimumWidth)
            parent.addView(child, LinearLayout.LayoutParams(if (vertical) 0 else axis, if (vertical) axis else 0, if (fixedAxis == null) 1f else 0f))
        } else {
            child.minimumWidth = max(child.minimumWidth, pixels)
            child.minimumHeight = max(child.minimumHeight, pixels)
            if (parent != null) addChild(parent, child)
        }
    }

    @JvmStatic fun configureScroll(view: View, horizontal: Boolean, vertical: Boolean, indicators: Boolean) {
        main()
        view.isHorizontalScrollBarEnabled = horizontal && indicators
        view.isVerticalScrollBarEnabled = vertical && indicators
        when (view) {
            is ScrollView -> view.isFillViewport = true
            is HorizontalScrollView -> view.isFillViewport = true
        }
    }
}
