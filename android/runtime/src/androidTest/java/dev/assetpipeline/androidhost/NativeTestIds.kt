package dev.assetpipeline.androidhost

import android.view.View
import android.view.ViewGroup
import org.hamcrest.Description
import org.hamcrest.Matcher
import org.hamcrest.TypeSafeMatcher

/** Automation identifiers never need to be spoken content descriptions. */
object NativeTestIds {
    fun withTestId(id: String): Matcher<View> = object : TypeSafeMatcher<View>() {
        override fun describeTo(description: Description) { description.appendText("native test identifier ").appendValue(id) }
        override fun matchesSafely(view: View) = NativeSemantics.testId(view) == id
    }
    fun find(root: View, id: String): View? {
        if (NativeSemantics.testId(root) == id) return root
        if (root is ViewGroup) for (index in 0 until root.childCount) find(root.getChildAt(index), id)?.let { return it }
        return null
    }
}
