package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.SystemClock
import android.view.View
import android.widget.EditText
import android.widget.ScrollView
import android.widget.HorizontalScrollView
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidFocusVisibilityTest {
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "focus-visibility"))
            .also { awaitText("Focus visibility") }
    }
    private fun view(activity: MainActivity, id: String) = requireNotNull(NativeTestIds.find(activity.findViewById(R.id.rendererMount), id))
    private fun editor(activity: MainActivity) = NativeSemantics.target(view(activity, "focus-distant-editor")) as EditText
    private fun scroll(activity: MainActivity) = view(activity, "focus-nested-scroll") as ScrollView
    private fun horizontal(activity: MainActivity) = scroll(activity).getChildAt(0) as HorizontalScrollView
    private fun awaitText(text: String) = assertTrue(UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text(text)), 5000L))
    private fun fullyVisible(field: View): Boolean {
        val visible = Rect()
        return field.getGlobalVisibleRect(visible) && visible.width() >= field.width && visible.height() >= field.height
    }
    private fun focusDistant(scenario: ActivityScenario<MainActivity>) {
        var expected = ""
        scenario.onActivity { activity ->
            expected = "Requests: " + ((view(activity, "focus-status") as TextView).text.toString().substringAfter(": ").toInt() + 1)
            assertTrue(view(activity, "focus-request").performClick())
        }
        awaitText(expected)
    }
    private fun awaitIme(scenario: ActivityScenario<MainActivity>, visible: Boolean) {
        val end = SystemClock.uptimeMillis() + 5000L
        var observed = false
        while (SystemClock.uptimeMillis() < end) {
            scenario.onActivity { observed = ViewCompat.getRootWindowInsets(it.window.decorView)?.isVisible(WindowInsetsCompat.Type.ime()) == visible }
            if (observed) return
            SystemClock.sleep(25)
        }
        fail("Keyboard visibility did not become $visible")
    }
    private fun close(scenario: ActivityScenario<MainActivity>) {
        scenario.close()
        InstrumentationRegistry.getInstrumentation().runOnMainSync { assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts()) }
    }
    @Test fun explicitFocusOverridesSavedNestedScrollAndKeepsTheEntireEditorVisible() {
        val scenario = launch()
        try {
            scenario.onActivity { activity ->
                assertEquals(0, scroll(activity).scrollY)
                assertEquals(0, horizontal(activity).scrollX)
                assertFalse(fullyVisible(editor(activity)))
            }
            focusDistant(scenario)
            scenario.onActivity { activity ->
                assertTrue(editor(activity).isFocused)
                assertTrue("New explicit focus must override the old horizontal viewport", horizontal(activity).scrollX > 0)
                assertTrue("New explicit focus must override the old vertical viewport", scroll(activity).scrollY > 0)
                assertTrue("The complete focused editor must be visible", fullyVisible(editor(activity)))
            }
            scenario.recreate()
            awaitText("Focus visibility")
            scenario.onActivity { assertTrue(editor(it).isFocused); assertTrue(fullyVisible(editor(it))) }
        } finally { close(scenario) }
    }
    @Test fun visibleKeyboardAndFocusedEditorReturnAfterActivityAndWindowRecreation() {
        val scenario = launch()
        try {
            focusDistant(scenario)
            var x = 0; var y = 0
            scenario.onActivity { activity ->
                val field = editor(activity)
                // The input visibility test is independent of the first test's
                // scroll assertion; exercise the real user tap/input method.
                field.requestRectangleOnScreen(Rect(0, 0, field.width, field.height), true)
            }
            // The scroll into view is asynchronous; read the tap point only once
            // the editor is entirely on screen, or a slow emulator injects the
            // tap at a stale, off-screen coordinate and UiDevice.click fails.
            val visibleDeadline = SystemClock.uptimeMillis() + 5000L
            var visible = false
            while (!visible && SystemClock.uptimeMillis() < visibleDeadline) {
                scenario.onActivity { activity ->
                    val field = editor(activity)
                    val bounds = Rect()
                    visible = field.getGlobalVisibleRect(bounds) && bounds.height() == field.height && bounds.width() == field.width
                    if (visible) { x = bounds.centerX(); y = bounds.centerY() }
                }
                if (!visible) SystemClock.sleep(50L)
            }
            assertTrue("Editor did not scroll fully into view", visible)
            assertTrue(UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).click(x, y))
            awaitIme(scenario, true)
            scenario.recreate()
            awaitText("Focus visibility")
            awaitIme(scenario, true)
            scenario.onActivity { assertTrue(editor(it).isFocused); assertTrue(fullyVisible(editor(it))) }
            // User Back hides the keyboard; later native refresh/recreation
            // must not reopen it merely because the editor retains focus.
            UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).pressBack()
            awaitIme(scenario, false)
            scenario.recreate()
            awaitText("Focus visibility")
            awaitIme(scenario, false)
            scenario.onActivity { assertTrue(editor(it).isFocused) }
        } finally { close(scenario) }
    }
}
