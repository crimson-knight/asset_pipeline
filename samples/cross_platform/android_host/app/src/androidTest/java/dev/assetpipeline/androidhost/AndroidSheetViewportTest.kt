package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.widget.NestedScrollView
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.espresso.matcher.RootMatchers.isDialog
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.google.android.material.bottomsheet.BottomSheetBehavior
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AndroidSheetViewportTest {
    private val device get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private fun launch() = ActivityScenario.launch<MainActivity>(Intent(
        ApplicationProvider.getApplicationContext<Context>(), MainActivity::class.java)
        .putExtra(MainActivity.EXTRA_APP_SLUG, "sheets-contract"))
    private fun appClick(id: String) = onView(NativeTestIds.withTestId(id)).perform(scrollTo(), click())
    private fun inside(id: String) = onView(NativeTestIds.withTestId(id)).inRoot(isDialog())
    /** Wait until the view's on-screen rectangle has not changed for 250 ms, then tap. */
    private fun tap(id: String) {
        val deadline = SystemClock.uptimeMillis() + 5000L
        var last: Rect? = null
        var stableSince = 0L
        while (SystemClock.uptimeMillis() < deadline) {
            var now: Rect? = null
            inside(id).check { view, error -> if (error != null) throw error; now = Rect().also { view.getGlobalVisibleRect(it) } }
            if (now != null && now == last) {
                if (stableSince == 0L) stableSince = SystemClock.uptimeMillis()
                if (SystemClock.uptimeMillis() - stableSince >= 250L) break
            } else stableSince = 0L
            last = now
            SystemClock.sleep(50L)
        }
        NativeTaps.tap({ inside(id) })
    }
    private fun await(text: String) = assertTrue("Missing native text: $text", device.wait(Until.hasObject(By.text(text)), 5000L))
    private fun gone() = assertTrue("Native sheet did not close", device.wait(Until.gone(By.text("Edit a native draft")), 5000L))
    private fun main(block: () -> Unit) = InstrumentationRegistry.getInstrumentation().runOnMainSync(block)
    private fun screenshot(name: String) {
        val directory = requireNotNull(InstrumentationRegistry.getInstrumentation().targetContext.getExternalFilesDir("sheet-detent-proof")).apply { mkdirs() }
        assertTrue(device.takeScreenshot(File(directory, "$name.png")))
    }
    private data class Parts(val frame: FrameLayout, val viewport: NestedScrollView, val editor: EditText)
    private fun parts(): Parts {
        var result: Parts? = null
        inside("sheet-draft").check { view, error ->
            if (error != null) throw error
            var ancestor = view.parent
            while (ancestor !is NestedScrollView && ancestor is View) ancestor = ancestor.parent
            result = Parts(requireNotNull(view.rootView.findViewById(com.google.android.material.R.id.design_bottom_sheet)),
                ancestor as NestedScrollView, NativeSemantics.target(view) as EditText)
        }
        return requireNotNull(result)
    }
    private fun geometry(shown: Parts, size: String, keyboard: Boolean = false) {
        // Measure only once the sheet frame has stopped moving: after a
        // recreation the keyboard lift animates the frame, and a read taken
        // mid-animation reports the pre-lift height.
        val deadline = SystemClock.uptimeMillis() + 5000L
        var last: Rect? = null
        var stableSince = 0L
        while (SystemClock.uptimeMillis() < deadline) {
            var now: Rect? = null
            main { now = Rect().also { shown.frame.getGlobalVisibleRect(it) } }
            if (now != null && now == last) {
                if (stableSince == 0L) stableSince = SystemClock.uptimeMillis()
                if (SystemClock.uptimeMillis() - stableSince >= 250L) break
            } else stableSince = 0L
            last = now
            SystemClock.sleep(50L)
        }
        geometryNow(shown, size, keyboard)
    }
    private fun geometryNow(shown: Parts, size: String, keyboard: Boolean) = main {
        val frame = Rect(); val viewport = Rect()
        assertTrue("$size sheet must be visible", shown.frame.getGlobalVisibleRect(frame))
        assertTrue("$size viewport must be visible", shown.viewport.getGlobalVisibleRect(viewport))
        assertEquals("$size viewport must fit its visible window, not extend below it", shown.viewport.height, viewport.height())
        val insets = requireNotNull(ViewCompat.getRootWindowInsets(shown.frame))
        assertEquals(keyboard, insets.isVisible(WindowInsetsCompat.Type.ime()))
        val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
        val ime = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
        val parentHeight = (shown.frame.parent as View).height
        val lift = maxOf(0, ime - bars.bottom)
        val expected = when (size) {
            "small" -> minOf(parentHeight - bars.top, parentHeight / 4 + lift)
            "medium" -> minOf(parentHeight - bars.top, parentHeight / 2 + lift)
            else -> parentHeight - bars.top
        }
        val tolerance = (2 * shown.frame.resources.displayMetrics.density).toInt()
        assertTrue("$size visible sheet height ${frame.height()} must match $expected", kotlin.math.abs(frame.height() - expected) <= tolerance)
        val containers = generateSequence(shown.viewport as View) { it.parent as? View }.joinToString("; ") {
            val xy = IntArray(2); it.getLocationOnScreen(xy)
            "${it.javaClass.simpleName} y=${xy[1]} h=${it.height} pt=${it.paddingTop} pb=${it.paddingBottom}"
        }
        assertTrue("Viewport bottom ${viewport.bottom} must meet system exclusion ${device.displayHeight - maxOf(bars.bottom, ime)}: $containers",
            kotlin.math.abs(viewport.bottom - (device.displayHeight - maxOf(bars.bottom, ime))) <= tolerance)
        InstrumentationRegistry.getInstrumentation().sendStatus(0, Bundle().apply {
            putString("sheet_geometry", "$size keyboard=$keyboard parent=$parentHeight frame=${frame.height()} viewport=${viewport.height()} bottom=${viewport.bottom}")
        })
    }
    private fun waitFor(message: String, condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 5000
        while (SystemClock.uptimeMillis() < deadline) {
            var ready = false
            main { ready = condition() }
            if (ready) return
            SystemClock.sleep(25)
        }
        fail(message)
    }
    private fun detent(scenario: ActivityScenario<MainActivity>, expected: String) {
        val previous = parts().frame
        scenario.onActivity { CrystalBridge.requestRender() }
        var decor: View? = null
        scenario.onActivity { decor = it.window.decorView }
        waitFor("Crystal detent did not become $expected") {
            // A render replaces the page, so do not retain its old label.
            val current = NativeTestIds.find(requireNotNull(decor), "sheet-detent")
            !previous.isAttachedToWindow && current != null &&
                (NativeSemantics.target(current) as TextView).text.toString() == "Current detent: $expected"
        }
    }
    private fun swipe(shown: Parts, down: Boolean) {
        var start = 0; var end = 0
        main {
            val xy = IntArray(2); shown.frame.getLocationOnScreen(xy)
            val density = shown.frame.resources.displayMetrics.density
            start = xy[1] + (20 * density).toInt()
            end = if (down) device.displayHeight - (32 * density).toInt() else (80 * density).toInt()
        }
        assertTrue(device.swipe(device.displayWidth / 2, start, device.displayWidth / 2, end, if (down) 12 else 40))
    }
    private fun close(scenario: ActivityScenario<MainActivity>) {
        scenario.onActivity {
            if (CrystalBridge.debugSessionState() == HostSession.State.FOREGROUND && CrystalBridge.debugDialogCount() > 0)
                NativeTestIds.find(it.window.decorView, "sheet-close-outside")?.performClick()
        }
        scenario.close()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(0, CrystalBridge.debugDialogCount())
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
        }
    }
    @Test fun everyDeclaredHeightHasAVisibleViewportAndReachableBottomAction() {
        val scenario = launch()
        try {
            await("Native sheets"); appClick("sheet-reset")
            val cases = listOf("medium-only" to "medium", "small-only" to "small", "large-only" to "large",
                "small-medium" to "small", "small-large" to "small", "medium-large" to "medium",
                "three-small" to "small", "medium" to "medium", "" to "large")
            for ((fixture, size) in cases) {
                appClick("sheet-open" + if (fixture.isEmpty()) "" else "-$fixture"); await("Edit a native draft")
                val shown = parts()
                geometry(shown, size)
                if (fixture.endsWith("-only")) screenshot(fixture)
                tap("sheet-chain")
                await("After the native sheet")
                lateinit var previousOpen: View
                scenario.onActivity { previousOpen = requireNotNull(NativeTestIds.find(it.window.decorView, "sheet-open")) }
                onView(NativeTestIds.withTestId("sheet-followup.action.0")).inRoot(isDialog()).perform(click())
                // Alert button dispatch schedules a whole-tree refresh. Do not
                // start the next fixture through a root that is being retired.
                // Require the real replacement, window focus and zero dialogs;
                // no retrying the tap or forcing production state is allowed.
                val readyDeadline = SystemClock.uptimeMillis() + 5000L
                var ready = false
                while (!ready && SystemClock.uptimeMillis() < readyDeadline) {
                    scenario.onActivity { activity ->
                        val current = NativeTestIds.find(activity.window.decorView, "sheet-open")
                        ready = current != null && current !== previousOpen && current.isAttachedToWindow &&
                            activity.hasWindowFocus() && CrystalBridge.debugDialogCount() == 0
                    }
                    if (!ready) SystemClock.sleep(25L)
                }
                assertTrue("Follow-up dismissal must finish before the next sheet fixture", ready)
            }
        } finally { close(scenario) }
    }
    @Test fun smallOnlyEditorKeepsItsDetentAndUsableKeyboardViewportAcrossRecreation() {
        val scenario = launch()
        try {
            await("Native sheets"); appClick("sheet-reset"); appClick("sheet-open-small-only")
            await("Edit a native draft"); geometry(parts(), "small")
            inside("sheet-draft").perform(scrollTo())
            var shown = parts()
            var x = 0; var y = 0
            main {
                val rect = Rect(); assertTrue(shown.editor.getGlobalVisibleRect(rect))
                assertEquals(shown.editor.height, rect.height()); x = rect.centerX(); y = rect.centerY()
            }
            assertTrue(device.click(x, y))
            waitFor("Small sheet keyboard did not open") { ViewCompat.getRootWindowInsets(shown.frame)?.isVisible(WindowInsetsCompat.Type.ime()) == true }
            val text = "Small 雪 😀 e\u0301 draft"
            main { shown.editor.setText(text); shown.editor.setSelection(2, 7) }
            inside("sheet-draft").check { _, error -> if (error != null) throw error }
            geometry(shown, "small", true)
            scenario.onActivity {
                assertTrue("Keyboard resize must not steal editor focus", shown.editor.isFocused)
                val output = Bundle()
                InstrumentationRegistry.getInstrumentation().callActivityOnSaveInstanceState(it, output)
                val saved = requireNotNull(NativeViewState.fromBundle(output.getBundle("asset_pipeline.native_sheet.v1")))
                assertTrue("Small sheet must capture visible keyboard metadata", saved.ime)
                assertEquals("Small sheet must capture its focused editor", 1, saved.entries.values.count { entry -> entry.focused })
                assertTrue(shown.editor.isFocused)
            }
            scenario.recreate(); await("Edit a native draft"); shown = parts()
            main { assertTrue("Small sheet editor focus did not restore", shown.editor.isFocused) }
            waitFor("Small sheet keyboard did not restore") { ViewCompat.getRootWindowInsets(shown.frame)?.isVisible(WindowInsetsCompat.Type.ime()) == true }
            inside("sheet-draft").check { _, error -> if (error != null) throw error }
            geometry(shown, "small", true)
            main {
                assertEquals(text, shown.editor.text.toString()); assertEquals(2, shown.editor.selectionStart); assertEquals(7, shown.editor.selectionEnd)
                assertTrue(shown.editor.isFocused)
                val rect = Rect(); assertTrue(shown.editor.getGlobalVisibleRect(rect)); assertEquals(shown.editor.height, rect.height())
            }
            screenshot("small-keyboard-restored")
            detent(scenario, "small")
            shown = parts()
            waitFor("Refreshed small sheet must restore its keyboard") { ViewCompat.getRootWindowInsets(shown.frame)?.isVisible(WindowInsetsCompat.Type.ime()) == true }
            assertTrue(device.pressBack()); await("Edit a native draft")
            waitFor("Back must hide the keyboard without dismissing the sheet") { ViewCompat.getRootWindowInsets(shown.frame)?.isVisible(WindowInsetsCompat.Type.ime()) == false }
            inside("sheet-draft").check { _, error -> if (error != null) throw error }
            geometry(shown, "small")
            main { assertEquals(1, CrystalBridge.debugDialogCount()); assertTrue(shown.editor.isFocused) }
            tap("sheet-chain"); await("After the native sheet")
            onView(NativeTestIds.withTestId("sheet-followup.action.0")).inRoot(isDialog()).perform(click())
        } finally { close(scenario) }
    }
    @Test fun realGesturesRespectAllowedMaximumAndLockedDismissal() {
        val scenario = launch()
        try {
            await("Native sheets"); appClick("sheet-reset")
            for ((fixture, maximum) in listOf("small-medium" to "medium", "small-large" to "large", "medium-large" to "large")) {
                appClick("sheet-open-$fixture"); await("Edit a native draft")
                var shown = parts(); swipe(shown, false)
                waitFor("Pair did not settle expanded") { BottomSheetBehavior.from(shown.frame).state == BottomSheetBehavior.STATE_EXPANDED }
                geometry(shown, maximum)
                detent(scenario, maximum); shown = parts(); geometry(shown, maximum)
                tap("sheet-done"); gone()
            }
            appClick("sheet-reset"); appClick("sheet-open-small-only"); await("Edit a native draft")
            swipe(parts(), true); gone()
            onView(NativeTestIds.withTestId("sheet-status")).perform(scrollTo()); await("Dismissals: 1; saves: 0; behind: 0")
            appClick("sheet-open-locked-small"); await("Edit a native draft")
            val locked = parts(); swipe(locked, true)
            inside("sheet-draft").check { _, error -> if (error != null) throw error }
            geometry(locked, "small")
            main { assertFalse(BottomSheetBehavior.from(locked.frame).isHideable); assertEquals(1, CrystalBridge.debugDialogCount()) }
            assertTrue(device.click(device.displayWidth / 2, device.displayHeight / 3))
            inside("sheet-draft").check { _, error -> if (error != null) throw error }
            geometry(locked, "small")
            scenario.onActivity { requireNotNull(NativeTestIds.find(it.window.decorView, "sheet-close-outside")).performClick() }
            gone(); onView(NativeTestIds.withTestId("sheet-status")).perform(scrollTo()); await("Dismissals: 2; saves: 0; behind: 0")
        } finally { close(scenario) }
    }
}
