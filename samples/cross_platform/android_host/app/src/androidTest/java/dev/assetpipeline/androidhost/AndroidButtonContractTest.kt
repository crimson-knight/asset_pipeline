package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.Gravity
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.google.android.material.button.MaterialButton
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Button contract: an explicit background and foreground color win over the
 * style's Material role, a border is the MaterialButton stroke, the line cap
 * and the text alignment are read, and a button that set none of them keeps
 * its role colors and its single line. */
@RunWith(AndroidJUnit4::class)
class AndroidButtonContractTest {
    private fun argb(r: Double, g: Double, b: Double): Int =
        Color.argb(255, (r * 255).roundToInt(), (g * 255).roundToInt(), (b * 255).roundToInt())

    @Test fun explicitColorsBordersLinesAndAlignmentReachTheMaterialButton() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val scenario = ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "button-contract"))
        try {
            assertTrue("Native text did not appear", UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text("Native button reads")), 10000L))
            scenario.onActivity { activity ->
                val decor = activity.window.decorView
                fun button(id: String): MaterialButton = requireNotNull(NativeTestIds.find(decor, id)) { "missing $id" } as MaterialButton
                val brandRed = argb(0.78, 0.09, 0.16)
                val ink = argb(0.12, 0.20, 0.24)
                val iosBlue = argb(0.0, 0.478, 1.0)

                val brand = button("button-brand")
                assertEquals("brand background tint", brandRed, requireNotNull(brand.backgroundTintList).defaultColor)
                assertEquals("brand text color", Color.WHITE, brand.currentTextColor)

                val plain = button("button-default")
                assertNotEquals("a default button keeps its Material role, not the brand red", brandRed, requireNotNull(plain.backgroundTintList).defaultColor)
                assertNotEquals("the declared foreground default is never painted", iosBlue, plain.currentTextColor)
                assertEquals("a default button stays on one line", 1, plain.lineCount)
                assertEquals("a default button is capped at one line", 1, plain.maxLines)

                val outlined = button("button-outlined")
                assertTrue("outlined stroke width ${outlined.strokeWidth}", outlined.strokeWidth >= 1)
                assertEquals("outlined stroke color", ink, requireNotNull(outlined.strokeColor).defaultColor)
                assertEquals("outlined text color", ink, outlined.currentTextColor)
                assertEquals("outlined background tint", Color.WHITE, requireNotNull(outlined.backgroundTintList).defaultColor)

                val wrap = button("button-wrap")
                assertEquals("no line cap", Int.MAX_VALUE, wrap.maxLines)
                assertTrue("the long label wrapped: ${wrap.lineCount} lines", wrap.lineCount >= 3)
                val capped = button("button-capped")
                assertEquals("capped at two lines", 2, capped.maxLines)
                assertEquals("shows two lines", 2, capped.lineCount)
                assertTrue("the cap truncates with an ellipsis", requireNotNull(capped.layout).getEllipsisCount(1) > 0)
                assertEquals("an uncapped label has no ellipsis", 0, requireNotNull(wrap.layout).getEllipsisCount(wrap.lineCount - 1))

                val leading = button("button-leading")
                val trailing = button("button-trailing")
                assertEquals("leading gravity", Gravity.START, leading.gravity and Gravity.RELATIVE_HORIZONTAL_GRAVITY_MASK)
                assertEquals("trailing gravity", Gravity.END, trailing.gravity and Gravity.RELATIVE_HORIZONTAL_GRAVITY_MASK)
                assertEquals("default gravity", Gravity.CENTER_HORIZONTAL, plain.gravity and Gravity.HORIZONTAL_GRAVITY_MASK)
                assertEquals("labels stay vertically centered", Gravity.CENTER_VERTICAL, leading.gravity and Gravity.VERTICAL_GRAVITY_MASK)
                val leadingLayout = requireNotNull(leading.layout) { "leading has no layout" }
                val trailingLayout = requireNotNull(trailing.layout) { "trailing has no layout" }
                assertTrue("the leading label starts at the text area's left edge: ${leadingLayout.getLineLeft(0)}", leadingLayout.getLineLeft(0) <= 2f)
                assertTrue("the trailing label ends at the text area's right edge: ${trailingLayout.getLineRight(0)} of ${trailingLayout.width}", trailingLayout.width - trailingLayout.getLineRight(0) <= 2f)
                assertTrue("the leading text area is wider than its label, so alignment is visible", leadingLayout.width - leadingLayout.getLineWidth(0) > 20f)
            }
        } finally { scenario.close() }
    }
}
