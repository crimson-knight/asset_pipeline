package dev.assetpipeline.androidhost

import android.view.ViewGroup

/** How tall the mounted root is. A tree whose root fills the screen
 * (`fill_screen!`) lays its own flexible rows out against the height it is
 * given, the way UIKit pins such a root to the screen. A scrolling host
 * container measures its child with no height bound whatever the child's
 * params say, and a mount inside it passes that on; the one measure spec
 * that stays exact under an unbounded parent is an explicit pixel height on
 * the child itself, so the root gets the container's bar-free height in
 * pixels. Any other root keeps its content height and the container
 * scrolls it. */
object MountPolicy {
    const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
    const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT

    /** The mounted root's layout height: WRAP for a root that hugs; for a
     * root that fills, the container's inner height in pixels once it has
     * one, MATCH when the mount has no scrolling container, and WRAP until
     * the first layout. */
    @JvmStatic fun rootHeight(rootFills: Boolean, hasContainer: Boolean, containerInnerHeight: Int): Int = when {
        !rootFills -> WRAP
        !hasContainer -> MATCH
        containerInnerHeight > 0 -> containerInnerHeight
        else -> WRAP
    }
}
