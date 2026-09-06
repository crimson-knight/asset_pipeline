package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.widget.EditText
import androidx.activity.BackEventCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.*
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.*
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidNavigationContractTest {
    private val device get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private fun awaitText(text: String) {
        assertTrue("Missing navigation screen: $text", device.wait(Until.hasObject(By.text(text)), 5000L))
    }
    private fun clickText(text: String) { onView(withText(text)).perform(scrollTo(), click()) }
    private fun assertBack(scenario: ActivityScenario<MainActivity>, expected: Boolean) {
        scenario.onActivity { activity ->
            assertEquals(expected, CrystalBridge.canNavigateBack())
            assertEquals(expected, activity.onBackPressedDispatcher.hasEnabledCallbacks())
        }
    }

    @Test fun nativeLinksToolbarAndSystemBackPreserveCrystalState() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val intent = Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "navigation")
        val scenario = ActivityScenario.launch<MainActivity>(intent)
        var baseline: CrystalBridge.NativeDebugCounts? = null
        try {
            awaitText("Navigation home")
            assertBack(scenario, false)
            scenario.onActivity { baseline = CrystalBridge.debugCounts() }
            onView(withText("Disabled navigation")).check(matches(org.hamcrest.Matchers.not(isEnabled())))
            clickText("Open details")
            awaitText("Navigation details")
            assertBack(scenario, true)
            scenario.onActivity { activity ->
                val gesture = BackEventCompat(0f, 100f, 0.5f, BackEventCompat.EDGE_LEFT)
                activity.onBackPressedDispatcher.dispatchOnBackStarted(gesture)
                activity.onBackPressedDispatcher.dispatchOnBackProgressed(gesture)
                activity.onBackPressedDispatcher.dispatchOnBackCancelled()
                assertTrue(CrystalBridge.canNavigateBack())
            }
            awaitText("Navigation details")
            // Real IME Back dismisses the keyboard before application Back.
            onView(isAssignableFrom(EditText::class.java)).perform(scrollTo(), click())
            var keyboardVisible = false
            val deadline = System.currentTimeMillis() + 5000L
            while (!keyboardVisible && System.currentTimeMillis() < deadline) {
                scenario.onActivity { activity ->
                    keyboardVisible = ViewCompat.getRootWindowInsets(activity.window.decorView)?.isVisible(WindowInsetsCompat.Type.ime()) == true
                }
                if (!keyboardVisible) Thread.sleep(25L)
            }
            assertTrue("The device keyboard must actually be visible before Back", keyboardVisible)
            device.pressBack()
            InstrumentationRegistry.getInstrumentation().waitForIdleSync()
            val hideDeadline = System.currentTimeMillis() + 5000L
            while (keyboardVisible && System.currentTimeMillis() < hideDeadline) {
                scenario.onActivity { activity ->
                    keyboardVisible = ViewCompat.getRootWindowInsets(activity.window.decorView)?.isVisible(WindowInsetsCompat.Type.ime()) == true
                }
                if (keyboardVisible) Thread.sleep(25L)
            }
            assertFalse("Back must dismiss the keyboard, not merely leave the route unchanged", keyboardVisible)
            awaitText("Navigation details")
            assertBack(scenario, true)
            onView(isAssignableFrom(EditText::class.java)).perform(scrollTo(), replaceText("Kept across navigation"), closeSoftKeyboard())
            clickText("Open settings")
            awaitText("Navigation settings")
            clickText("Change shared state")
            awaitText("Navigation count: 1")
            clickText("Open nested detail")
            awaitText("Nested detail")
            // The deepest visible stack consumes Back first.
            device.pressBack()
            awaitText("Nested root")
            awaitText("Navigation settings")
            scenario.recreate()
            awaitText("Navigation settings")
            awaitText("Navigation count: 1")
            assertBack(scenario, true)
            device.pressBack()
            awaitText("Navigation details")
            onView(isAssignableFrom(EditText::class.java)).check(matches(withText("Kept across navigation")))
            // Real toolbar Up is separately wired, not a test-only back helper.
            onView(withContentDescription("Navigate up")).perform(scrollTo()).check { view, error ->
                if (error != null) throw error
                // Dispatch the native control's accessibility click. A heavily
                // scheduled emulator can stretch an injected touch into a
                // tooltip long-press, which is deliberately not a click.
                assertTrue(view.performAccessibilityAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK, null))
            }
            awaitText("Navigation home")
            assertBack(scenario, false)
            scenario.onActivity { assertEquals(baseline, CrystalBridge.debugCounts()) }

            // Programmatic stack reset and repeated teardown must not leak.
            repeat(5) {
                clickText("Open details")
                awaitText("Navigation details")
                clickText("Open settings")
                awaitText("Navigation settings")
                clickText("Return to home")
                awaitText("Navigation home")
                assertBack(scenario, false)
                scenario.onActivity { assertEquals(baseline, CrystalBridge.debugCounts()) }
            }
            // At root, the callback is disabled and Android backgrounds/exits
            // the Activity instead of swallowing Back or closing Crystal session.
            device.pressBack()
            assertTrue(device.wait(Until.gone(By.text("Navigation home")), 5000L))
            InstrumentationRegistry.getInstrumentation().waitForIdleSync()
            // The predictive back-to-home animation can hide the live view
            // before Activity.onStop. Wait for the real lifecycle transition.
            val stopDeadline = System.currentTimeMillis() + 5000L
            while (scenario.state != Lifecycle.State.CREATED && scenario.state != Lifecycle.State.DESTROYED && System.currentTimeMillis() < stopDeadline) {
                Thread.sleep(25L)
            }
            assertTrue("Root Back must background or finish the Activity; actual=${scenario.state}",
                scenario.state == Lifecycle.State.CREATED || scenario.state == Lifecycle.State.DESTROYED)
        } finally { scenario.close() }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
            assertFalse(CrystalBridge.canNavigateBack())
            assertFalse(CrystalBridge.navigateBack())
        }
        val reopened = ActivityScenario.launch<MainActivity>(intent)
        try {
            awaitText("Navigation home")
            assertBack(reopened, false)
            clickText("Open details")
            awaitText("Navigation details")
            onView(isAssignableFrom(EditText::class.java)).check(matches(withText("Kept across navigation")))
            device.pressBack()
            awaitText("Navigation home")
        } finally { reopened.close() }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
        }
    }
}
