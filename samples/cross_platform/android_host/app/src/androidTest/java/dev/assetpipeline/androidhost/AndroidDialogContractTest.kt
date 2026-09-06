package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.espresso.matcher.RootMatchers.isDialog
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AndroidDialogContractTest {
    private val device get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private fun awaitText(text: String) = assertTrue("Expected native dialog text: $text", device.wait(Until.hasObject(By.text(text)), 10_000L))
    private fun gone(text: String) = assertTrue("Native window did not close", device.wait(Until.gone(By.text(text)), 5000L))
    /** Tap only once the control has stopped moving; a slow emulator can relayout between lookup and tap. */
    private fun clickId(id: String) {
        val deadline = android.os.SystemClock.uptimeMillis() + 5000L
        var last: android.graphics.Rect? = null
        var stableSince = 0L
        while (android.os.SystemClock.uptimeMillis() < deadline) {
            var now: android.graphics.Rect? = null
            onView(NativeTestIds.withTestId(id)).perform(scrollTo()).check { view, error -> if (error != null) throw error; now = android.graphics.Rect().also { view.getGlobalVisibleRect(it) } }
            if (now != null && now == last) {
                if (stableSince == 0L) stableSince = android.os.SystemClock.uptimeMillis()
                if (android.os.SystemClock.uptimeMillis() - stableSince >= 250L) break
            } else stableSince = 0L
            last = now
            android.os.SystemClock.sleep(50L)
        }
        onView(NativeTestIds.withTestId(id)).perform(click())
    }
    private fun nativeButton(text: String) = onView(withText(text)).inRoot(isDialog())
    private fun status(actions: Int = 0, cancels: Int = 0, confirms: Int = 0, underlying: Int = 0) =
        awaitText("Actions: $actions; cancels: $cancels; confirms: $confirms; underlying: $underlying")
    private fun count(expected: Int) = InstrumentationRegistry.getInstrumentation().runOnMainSync {
        assertEquals(expected, CrystalBridge.debugDialogCount())
    }
    private fun screenshot(name: String) {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val folder = requireNotNull(context.getExternalFilesDir("dialog-proof")).apply { mkdirs() }
        assertTrue(device.takeScreenshot(File(folder, "$name.png")))
    }
    private fun tapOutside(scenario: ActivityScenario<MainActivity>) {
        val windowBounds = Rect()
        nativeButton("Continue").check { view, error ->
            if (error != null) throw error
            val decor = view.rootView
            val origin = IntArray(2).also(decor::getLocationOnScreen)
            windowBounds.set(origin[0], origin[1], origin[0] + decor.width, origin[1] + decor.height)
            val flags = (decor.layoutParams as WindowManager.LayoutParams).flags
            assertEquals(0, flags and WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)
            assertEquals(0, flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE)
            assertNotEquals(0, flags and WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        }
        // Measure AFTER opening: scrollTo/recreation can change the underlying
        // viewport. Tap a real visible control whose centre is outside the
        // dialog window, not a stale coordinate that may land inside it.
        var point: Pair<Int, Int>? = null
        scenario.onActivity { activity ->
            for (id in listOf("dialog-underlying", "dialog-open-confirmation", "dialog-open-default", "dialog-open-alert")) {
                val view = requireNotNull(NativeTestIds.find(activity.window.decorView, id))
                val visible = Rect()
                if (view.getGlobalVisibleRect(visible) && !visible.isEmpty &&
                    !windowBounds.contains(visible.centerX(), visible.centerY())) {
                    point = visible.centerX() to visible.centerY()
                    break
                }
            }
        }
        val (x, y) = requireNotNull(point) { "No visible underlying control lies outside native window $windowBounds" }
        assertTrue(device.click(x, y))
    }
    @Test fun invalidDescriptorsAndSimultaneousPresentationsFailWithoutOpeningWindows() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_APP_SLUG, "dialogs-contract")).use { scenario ->
            scenario.onActivity { activity ->
                val baseline = CrystalBridge.debugCounts()
                val anchor = NativeDialogAnchor(activity)
                val invalid = """{"version":1,"title":"PRIVATE_DIALOG_SENTINEL","message":"","actions":[],"cancel":1}"""
                val error = assertThrows(IllegalArgumentException::class.java) { NativeDialogs.configure(anchor, invalid) }
                assertFalse(error.toString().contains("PRIVATE_DIALOG_SENTINEL"))
                assertNull(error.cause)
                assertNull(anchor.descriptor)
                val root = FrameLayout(activity)
                for (index in 0..1) {
                    val item = NativeDialogAnchor(activity)
                    NativeDialogs.configure(item, """{"version":1,"title":"A","message":"B","actions":[{"label":"OK","style":"default","token":1}],"cancel":2}""")
                    NativeViewState.mark(item, "dialog-$index", "Alert", "")
                    root.addView(item)
                }
                val host = NativeDialogHost(activity, null)
                try {
                    assertThrows(IllegalArgumentException::class.java) { host.synchronize(root, "test") }
                    assertEquals(0, host.activeCount)
                    assertEquals(HostSession.State.FOREGROUND, CrystalBridge.debugSessionState())
                } finally { host.close() }
                assertEquals(baseline, CrystalBridge.debugCounts())
                assertEquals(0, CrystalBridge.debugDialogCount())
            }
        }
    }
    @Test fun publicRootReplacementRetiresTheOldWindowBeforeReleasingItsCallbacks() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_APP_SLUG, "dialogs-contract")).use { scenario ->
            clickId("dialog-reset")
            clickId("dialog-open-alert"); awaitText("Native alert 雪 😀"); count(1)
            var retiredButton: View? = null
            nativeButton("Continue").check { view, error ->
                if (error != null) throw error
                retiredButton = view
            }
            scenario.onActivity { activity ->
                val second = NativeScreenHost(activity, FrameLayout(activity))
                try {
                    assertThrows(IllegalStateException::class.java) { second.render("dialogs-contract") }
                    assertEquals(1, CrystalBridge.debugDialogCount())
                    assertEquals(HostSession.State.FOREGROUND, CrystalBridge.debugSessionState())
                } finally { second.close() }
                assertEquals(1, CrystalBridge.debugDialogCount())
                assertNotNull(CrystalBridge.renderStudy(activity, "dialogs-contract"))
                assertEquals(0, CrystalBridge.debugDialogCount())
                assertFalse(requireNotNull(retiredButton).hasOnClickListeners())
                assertFalse(requireNotNull(retiredButton).performClick())
                assertEquals(HostSession.State.FOREGROUND, CrystalBridge.debugSessionState())
                // Clear retained model state without dispatching a released
                // underlying View listener; the new root owns these tokens.
                val replacement = requireNotNull(CrystalBridge.renderStudy(activity, "dialogs-contract"))
                assertTrue(requireNotNull(NativeTestIds.find(replacement, "dialog-close-all")).performClick())
            }
            gone("Native alert 雪 😀")
        }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
            assertEquals(0, CrystalBridge.debugDialogCount())
        }
    }
    @Test fun nativeWindowsPreserveOwnershipAndDeliverOnlyRealUserOutcomes() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        for (appearance in listOf("light", "dark")) {
            val scenario = ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_APP_SLUG, "dialogs-contract")
                .putExtra(MainActivity.EXTRA_STUDY_APPEARANCE, appearance))
            try {
                awaitText("Native dialogs")
                clickId("dialog-reset"); status(); count(0)
                var activityToken: Any? = null
                scenario.onActivity { activity ->
                    activityToken = activity.window.decorView.windowToken
                }
                clickId("dialog-open-alert"); awaitText("Native alert 雪 😀"); count(1)
                var stale: View? = null
                nativeButton("Continue").check { view, error ->
                    if (error != null) throw error
                    assertTrue(view is Button)
                    assertNotEquals("A dialog must have its own Android window", activityToken, view.windowToken)
                    assertEquals("Native alert 雪 😀", ViewCompat.getAccessibilityPaneTitle(view.rootView)?.toString())
                    assertEquals("dialog-alert.action.1", NativeSemantics.testId(view))
                    assertTrue(view.height >= (48 * view.resources.displayMetrics.density).toInt())
                    view.isFocusableInTouchMode = true; assertTrue(view.requestFocus()); stale = view
                }
                screenshot("alert-$appearance")
                scenario.recreate(); awaitText("Native alert 雪 😀"); count(1)
                nativeButton("Continue").check { view, error ->
                    if (error != null) throw error
                    assertTrue("Focused dialog action should survive recreation", view.isFocused)
                }
                InstrumentationRegistry.getInstrumentation().runOnMainSync {
                    assertFalse("Retired window must not retain its listener", requireNotNull(stale).hasOnClickListeners())
                    assertFalse(requireNotNull(stale).performClick())
                }
                stale = null
                scenario.moveToState(Lifecycle.State.CREATED); count(0); gone("Native alert 雪 😀")
                scenario.moveToState(Lifecycle.State.RESUMED); awaitText("Native alert 雪 😀"); count(1)
                nativeButton("Continue").perform(click()); gone("Native alert 雪 😀"); status(actions = 1); count(0)

                clickId("dialog-open-alert"); awaitText("Native alert 雪 😀")
                assertTrue(device.pressBack()); gone("Native alert 雪 😀"); status(actions = 1, cancels = 1); count(0)
                clickId("dialog-open-alert"); awaitText("Native alert 雪 😀")
                tapOutside(scenario)
                gone("Native alert 雪 😀"); status(actions = 1, cancels = 2, underlying = 0); count(0)
                gone("Delete this draft?"); gone("Default native action")

                clickId("dialog-open-confirmation"); awaitText("Delete this draft?")
                screenshot("confirmation-$appearance")
                nativeButton("Delete draft").perform(click()); gone("Delete this draft?")
                status(actions = 1, cancels = 2, confirms = 1)
                clickId("dialog-open-confirmation"); awaitText("Delete this draft?")
                nativeButton("Keep draft").perform(click()); gone("Delete this draft?")
                status(actions = 1, cancels = 3, confirms = 1)

                clickId("dialog-open-alert"); awaitText("Native alert 雪 😀")
                // This is an application-driven change, not a claim that a
                // physical tap can reach an obscured underlying control.
                scenario.onActivity { activity ->
                    assertTrue(requireNotNull(NativeTestIds.find(activity.window.decorView, "dialog-close-all")).performClick())
                }
                gone("Native alert 雪 😀"); status(actions = 1, cancels = 3, confirms = 1); count(0)
                clickId("dialog-open-default"); awaitText("Default native action")
                nativeButton("OK").perform(click()); gone("Default native action"); count(0)
            } finally { scenario.close() }
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                assertEquals(0, CrystalBridge.debugDialogCount())
                assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
                assertEquals(Pair(0, 0), CrystalBridge.debugPendingServices())
            }
        }
    }
}
