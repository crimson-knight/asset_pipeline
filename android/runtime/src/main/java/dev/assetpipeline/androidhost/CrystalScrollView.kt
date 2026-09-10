package dev.assetpipeline.androidhost

import android.content.Context
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.widget.ScrollView

/**
 * A vertical viewport that keeps the vertical drags it can consume and hands
 * them back at its edge, on every Android skin (see [ScrollGesturePolicy]).
 */
class CrystalScrollView(context: Context) : ScrollView(context) {
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop
    private var downY = 0f
    private var claimed = false

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downY = event.y
                claimed = ScrollGesturePolicy.claimsOnDown(canScrollVertically(1), canScrollVertically(-1))
                if (claimed) parent?.requestDisallowInterceptTouchEvent(true)
            }
            MotionEvent.ACTION_MOVE -> if (claimed &&
                ScrollGesturePolicy.onMove(event.y - downY, touchSlop, canScrollVertically(1), canScrollVertically(-1)) ==
                ScrollGesturePolicy.Claim.YIELD) release()
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> if (claimed) release()
        }
        return super.dispatchTouchEvent(event)
    }

    private fun release() {
        claimed = false
        parent?.requestDisallowInterceptTouchEvent(false)
    }
}
