package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.os.SystemClock
import android.view.View
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import kotlin.math.abs
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/** Host viewport contract: the report Crystal lays out with is the mount's
 * column and the bar-free visible height the host measures, it settles with
 * at most one refresh, a label wraps at it, and a rotated host reports its
 * new size. The expectations are measured from the sample host's own views,
 * never derived through the runtime's policy. */
@RunWith(AndroidJUnit4::class)
class AndroidViewportContractTest {
    private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "viewport-contract"))
    }
    private fun awaitText(text: String) = assertTrue("Native text did not appear: $text",
        device.wait(Until.hasObject(By.text(text)), 10000L))
    private fun waitFor(message: String, condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 10000L
        while (SystemClock.uptimeMillis() < deadline) {
            if (condition()) return
            SystemClock.sleep(50L)
        }
        fail(message)
    }
    /** The trailing number of a metric label, or -1 when the label is not on screen. */
    private fun metric(scenario: ActivityScenario<MainActivity>, id: String): Double {
        var value = -1.0
        scenario.onActivity { activity ->
            val label = NativeTestIds.find(activity.window.decorView, id) as? TextView
            value = label?.text?.toString()?.substringAfterLast(' ')?.toDoubleOrNull() ?: -1.0
        }
        return value
    }
    /** What the sample host laid out: it pads its scroll container by the
     * system bars and the keyboard, so the tree's column is the mount's width
     * and the visible height is the container's inner height while the
     * keyboard is hidden. */
    private data class Laid(val widthDp: Double, val heightDp: Double, val density: Float, val keyboard: Boolean)
    private fun laid(scenario: ActivityScenario<MainActivity>): Laid {
        var value: Laid? = null
        scenario.onActivity { activity ->
            val mount = activity.findViewById<View>(R.id.rendererMount)
            val container = activity.findViewById<View>(R.id.hostViewport)
            val density = activity.resources.displayMetrics.density
            val keyboard = ViewCompat.getRootWindowInsets(container)?.isVisible(WindowInsetsCompat.Type.ime()) == true
            value = Laid(mount.width / density.toDouble(),
                (container.height - container.paddingTop - container.paddingBottom) / density.toDouble(), density, keyboard)
        }
        return requireNotNull(value)
    }
    /** Waits until the width label agrees with the laid-out mount. */
    private fun awaitReport(scenario: ActivityScenario<MainActivity>, message: String): Laid {
        val deadline = SystemClock.uptimeMillis() + 10000L
        while (true) {
            val current = laid(scenario)
            val shown = metric(scenario, "viewport-width")
            if (!current.keyboard && current.widthDp > 0 && abs(shown - current.widthDp) <= 0.15) return current
            if (SystemClock.uptimeMillis() >= deadline) fail("$message (laid ${current.widthDp}, shown $shown, keyboard ${current.keyboard})")
            SystemClock.sleep(100L)
        }
    }

    @Test fun theReportIsTheMountsColumnAndTheBarFreeHeightAndALabelWrapsAtIt() {
        val scenario = launch()
        try {
            awaitText("Native viewport")
            val first = metric(scenario, "viewport-renders")
            val current = awaitReport(scenario, "The report did not settle on the laid-out mount")
            assertTrue("At most one refresh corrects the pre-layout report: ${metric(scenario, "viewport-renders")} after $first",
                metric(scenario, "viewport-renders") <= first + 1)
            assertEquals(current.heightDp, metric(scenario, "viewport-height"), 0.15)
            for (edge in listOf("top", "bottom", "left", "right"))
                assertEquals("A host that pads by the bars leaves no $edge inset", 0.0, metric(scenario, "viewport-$edge"), 0.15)
            assertEquals(current.density.toDouble(), metric(scenario, "viewport-density"), 0.06)
            scenario.onActivity { activity ->
                val decor = activity.window.decorView
                val bar = requireNotNull(NativeTestIds.find(decor, "viewport-bar")) { "missing bar" }
                val wrap = requireNotNull(NativeTestIds.find(decor, "viewport-wrap")) { "missing wrap label" } as TextView
                val column = ((current.widthDp - 36.0) * current.density).roundToInt()
                assertTrue("The bar is the content column: ${bar.width} of $column px", abs(bar.width - column) <= 1)
                assertTrue("The label wraps at the column: ${wrap.width} px, ${wrap.lineCount} lines, column $column",
                    wrap.lineCount >= 2 && wrap.width <= column && wrap.width >= column * 7 / 10)
                val reported = requireNotNull(activity.debugViewport()) { "the host reported nothing" }
                assertEquals("The host's last report is what the tree printed", current.widthDp, reported.widthDp, 0.01)
            }
        } finally { scenario.close() }
    }

    @Test fun aRotatedHostReportsItsNewSize() {
        val rotation = device.displayRotation
        val scenario = launch()
        var requested = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        try {
            awaitText("Native viewport")
            val portrait = awaitReport(scenario, "The portrait report did not settle")
            scenario.onActivity {
                requested = it.requestedOrientation
                it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            }
            waitFor("The host did not reach landscape") { device.displayWidth > device.displayHeight }
            awaitText("Native viewport")
            val landscape = awaitReport(scenario, "The rotated host did not report its size")
            assertTrue("Landscape is wider than portrait: ${landscape.widthDp} after ${portrait.widthDp}", landscape.widthDp > portrait.widthDp)
            assertEquals(landscape.heightDp, metric(scenario, "viewport-height"), 0.15)
        } finally {
            try { scenario.onActivity { it.requestedOrientation = requested } } finally { scenario.close() }
            waitFor("The orientation override was not released") { device.displayRotation == rotation }
        }
    }
}
