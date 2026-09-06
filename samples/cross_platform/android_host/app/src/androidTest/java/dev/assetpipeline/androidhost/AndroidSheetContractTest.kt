package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.SystemClock
import android.os.Bundle
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.isRoot
import androidx.test.espresso.ViewInteraction
import android.os.Parcel
import android.view.View
import android.view.ViewGroup
import android.view.KeyEvent
import android.view.inputmethod.BaseInputConnection
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.widget.NestedScrollView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.Lifecycle
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
class AndroidSheetContractTest {
    private val device get() = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private fun launch(appearance: String = "light") = ActivityScenario.launch<MainActivity>(
        Intent(ApplicationProvider.getApplicationContext<Context>(), MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_APP_SLUG, "sheets-contract")
            .putExtra(MainActivity.EXTRA_STUDY_APPEARANCE, appearance))
    private fun await(text: String) = assertTrue("Missing native text: $text", device.wait(Until.hasObject(By.text(text)), 10_000L))
    private fun gone() = assertTrue("Native sheet did not close", device.wait(Until.gone(By.text("Edit a native draft")), 5000L))
    private fun appClick(id: String) = onView(NativeTestIds.withTestId(id)).perform(scrollTo(), click())
    /** Wait until the view's on-screen rectangle has not changed for 250 ms. */
    private fun awaitStable(id: String) {
        val deadline = SystemClock.uptimeMillis() + 5000L
        var last: android.graphics.Rect? = null
        var stableSince = 0L
        while (SystemClock.uptimeMillis() < deadline) {
            var now: android.graphics.Rect? = null
            inside(id).check { view, error -> if (error != null) throw error; now = android.graphics.Rect().also { view.getGlobalVisibleRect(it) } }
            if (now != null && now == last) {
                if (stableSince == 0L) stableSince = SystemClock.uptimeMillis()
                if (SystemClock.uptimeMillis() - stableSince >= 250L) return
            } else stableSince = 0L
            last = now
            SystemClock.sleep(50L)
        }
        throw AssertionError("View $id did not stop moving")
    }
    /**
     * The sheet window is created from a Crystal callback after the opening
     * tap returns. Espresso's root picker gives up quickly when no root matches
     * `isDialog()`, which a slower emulator can hit; wait for it explicitly.
     */
    private fun awaitDialogRoot() {
        val deadline = SystemClock.uptimeMillis() + 15000L
        while (true) {
            try {
                onView(isRoot()).inRoot(isDialog()).check(matches(isDisplayed()))
                return
            } catch (missing: androidx.test.espresso.NoMatchingRootException) {
                if (SystemClock.uptimeMillis() >= deadline) throw missing
                SystemClock.sleep(50L)
            }
        }
    }
    private fun inside(id: String): ViewInteraction { awaitDialogRoot(); return onView(NativeTestIds.withTestId(id)).inRoot(isDialog()) }
    private fun editor(block: (EditText) -> Unit) = inside("sheet-draft").check { view, error ->
        if (error != null) throw error
        block(NativeSemantics.target(view) as EditText)
    }
    private fun count(expected: Int) = InstrumentationRegistry.getInstrumentation().runOnMainSync {
        assertEquals(expected, CrystalBridge.debugDialogCount())
    }
    private fun ime(expected: Boolean) {
        val deadline = SystemClock.uptimeMillis() + 5000
        while (SystemClock.uptimeMillis() < deadline) {
            var matches = false
            editor { matches = ViewCompat.getRootWindowInsets(it)?.isVisible(WindowInsetsCompat.Type.ime()) == expected }
            if (matches) return
            SystemClock.sleep(25)
        }
        fail("Sheet keyboard visibility did not become $expected")
    }
    private fun screenshot(name: String) {
        val folder = requireNotNull(InstrumentationRegistry.getInstrumentation().targetContext.getExternalFilesDir("sheet-proof")).apply { mkdirs() }
        assertTrue(device.takeScreenshot(File(folder, "$name.png")))
    }
    private fun keyboardViewport() {
        editor { field ->
            val insets = requireNotNull(ViewCompat.getRootWindowInsets(field))
            assertTrue(insets.isVisible(WindowInsetsCompat.Type.ime()))
            var ancestor = field.parent
            while (ancestor !is NestedScrollView && ancestor is View) ancestor = ancestor.parent
            val viewport = ancestor as NestedScrollView
            val bounds = Rect()
            assertTrue(viewport.getGlobalVisibleRect(bounds))
            val keyboardTop = device.displayHeight - insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
            val tolerance = (8 * field.resources.displayMetrics.density).toInt()
            assertTrue("Sheet viewport bottom ${bounds.bottom} must meet keyboard top $keyboardTop",
                kotlin.math.abs(bounds.bottom - keyboardTop) <= tolerance)
        }
    }
    private fun metadataOnly(scenario: ActivityScenario<MainActivity>, text: String) {
        fun bytes(bundle: Bundle): ByteArray {
            val parcel = Parcel.obtain()
            return try { parcel.writeBundle(bundle); parcel.marshall() } finally { parcel.recycle() }
        }
        fun contains(haystack: ByteArray, needle: ByteArray): Boolean =
            (0..haystack.size - needle.size).any { offset -> needle.indices.all { haystack[offset + it] == needle[it] } }
        scenario.onActivity {
            val output = Bundle()
            InstrumentationRegistry.getInstrumentation().callActivityOnSaveInstanceState(it, output)
            val sheet = requireNotNull(output.getBundle("asset_pipeline.native_sheet.v1"))
            assertNotNull(NativeViewState.fromBundle(sheet))
            assertTrue(bytes(sheet).size <= NativeViewState.MAX_SAVED_BYTES)
            val actual = bytes(output)
            val control = bytes(Bundle().apply { putString("positive-control", text) })
            val utf8 = text.toByteArray(Charsets.UTF_8)
            val utf16 = text.toByteArray(Charsets.UTF_16LE)
            assertTrue(contains(control, utf8) || contains(control, utf16))
            assertFalse(contains(actual, utf8)); assertFalse(contains(actual, utf16))
        }
    }
    private fun status(dismissals: Int, saves: Int = 0) {
        onView(NativeTestIds.withTestId("sheet-status")).perform(scrollTo())
        await("Dismissals: $dismissals; saves: $saves; behind: 0")
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
            assertEquals(Pair(0, 0), CrystalBridge.debugPendingServices())
        }
    }
    @Test fun nativeSheetDismissalDetentsAndRetiredControlsAreOwnedExactlyOnce() {
        for (appearance in listOf("light", "dark")) {
            val scenario = launch(appearance)
            try {
                await("Native sheets"); appClick("sheet-reset"); status(0)
                var token: Any? = null
                scenario.onActivity { token = it.window.decorView.windowToken }
                appClick("sheet-open"); await("Edit a native draft"); count(1)
                var oldButton: View? = null
                inside("sheet-done").check { view, error ->
                    if (error != null) throw error
                    assertNotEquals(token, view.windowToken)
                    val frame = requireNotNull(view.rootView.findViewById<FrameLayout>(com.google.android.material.R.id.design_bottom_sheet))
                    assertEquals(BottomSheetBehavior.STATE_EXPANDED, BottomSheetBehavior.from(frame).state)
                    assertTrue(frame.height > view.resources.displayMetrics.heightPixels / 2)
                    oldButton = view
                }
                screenshot("sheet-$appearance")
                inside("sheet-done").perform(scrollTo(), click()); gone(); status(1); count(0)
                InstrumentationRegistry.getInstrumentation().runOnMainSync { requireNotNull(oldButton).performClick() }
                status(1); count(0)

                appClick("sheet-open"); await("Edit a native draft")
                inside("sheet-presenter-done").perform(scrollTo(), click()); gone(); status(2)
                appClick("sheet-open"); await("Edit a native draft"); ime(false)
                assertTrue(device.pressBack()); gone(); status(3)

                appClick("sheet-open-medium"); await("Edit a native draft"); ime(false)
                var outsideY = 0
                inside("sheet-draft").check { view, error ->
                    if (error != null) throw error
                    val frame = requireNotNull(view.rootView.findViewById<FrameLayout>(com.google.android.material.R.id.design_bottom_sheet))
                    assertEquals(BottomSheetBehavior.STATE_HALF_EXPANDED, BottomSheetBehavior.from(frame).state)
                    val location = IntArray(2); frame.getLocationOnScreen(location)
                    outsideY = location[1] - (24 * view.resources.displayMetrics.density).toInt()
                    assertTrue(outsideY > 100)
                }
                assertTrue(device.click(device.displayWidth / 2, outsideY)); gone(); status(4)

                appClick("sheet-open-locked"); await("Edit a native draft"); ime(false)
                // A locked dialog intentionally leaves Back unhandled; the
                // injection helper's Boolean is not its dismissal contract.
                InstrumentationRegistry.getInstrumentation().sendKeyDownUpSync(KeyEvent.KEYCODE_BACK)
                await("Edit a native draft"); count(1)
                inside("sheet-draft").check { view, error ->
                    if (error != null) throw error
                    val frame = requireNotNull(view.rootView.findViewById<FrameLayout>(com.google.android.material.R.id.design_bottom_sheet))
                    assertFalse(BottomSheetBehavior.from(frame).isHideable)
                }
                scenario.onActivity { activity ->
                    val close = requireNotNull(NativeTestIds.find(activity.window.decorView, "sheet-close-outside"))
                    assertTrue(close.performClick()); assertTrue(close.performClick())
                }
                gone(); status(5); count(0)
            } finally { close(scenario) }
        }
    }
    @Test fun nativeEditorCompositionSelectionAndKeyboardSurviveWindowReplacement() {
        val scenario = launch()
        try {
            await("Native sheets"); appClick("sheet-reset")
            appClick("sheet-open"); await("Edit a native draft")
            var x = 0; var y = 0
            editor { view ->
                val location = IntArray(2); view.getLocationOnScreen(location)
                x = location[0] + view.width / 2; y = location[1] + view.height / 2
            }
            assertTrue(device.click(x, y)); ime(true)
            val text = "Sheet 雪 😀 e\u0301 draft"
            editor { it.setText(text); it.setSelection(2, 7) }
            await(text); ime(true); keyboardViewport()
            metadataOnly(scenario, text)
            screenshot("sheet-keyboard")
            scenario.recreate(); await("Edit a native draft"); ime(true)
            keyboardViewport()
            editor {
                assertEquals(text, it.text.toString()); assertEquals(2, it.selectionStart); assertEquals(7, it.selectionEnd)
                assertTrue(it.isFocused)
                val rect = Rect()
                assertTrue(it.getGlobalVisibleRect(rect)); assertEquals(it.height, rect.height())
            }
            var old: EditText? = null
            var connection: InputConnection? = null
            editor {
                old = it
                connection = requireNotNull(it.onCreateInputConnection(EditorInfo()))
                assertTrue(connection!!.beginBatchEdit())
                connection!!.finishComposingText()
                assertTrue(connection!!.setComposingText("compose", 1))
                assertTrue(BaseInputConnection.getComposingSpanStart(it.text) >= 0)
            }
            var deferredBefore = 0
            scenario.onActivity { deferredBefore = it.debugViewStateCounts().first; CrystalBridge.requestRender() }
            SystemClock.sleep(600)
            // The test intentionally keeps an IME batch open. Check its exact
            // live editor on the main looper without asking Espresso to wait
            // for the entire animated composing window to become idle first.
            scenario.onActivity {
                assertTrue("State refresh must retain the composing editor", old!!.isAttachedToWindow)
                assertTrue(NativeWindowScope.allows(old))
                assertTrue(old!!.isFocused)
                assertTrue(BaseInputConnection.getComposingSpanStart(old!!.text) >= 0)
                assertTrue(it.debugViewStateCounts().first > deferredBefore)
            }
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                assertTrue(connection!!.finishComposingText())
                // EditText returns true for the final batch on API 31/32 due
                // to its documented off-by-one, corrected in API 33. Do not
                // drain an extra batch or discard the refresh/ownership checks.
                assertEquals(android.os.Build.VERSION.SDK_INT < 33, connection!!.endBatchEdit())
            }
            val deadline = SystemClock.uptimeMillis() + 5000
            var changed = false
            while (SystemClock.uptimeMillis() < deadline && !changed) {
                editor { changed = it !== old }
                if (!changed) SystemClock.sleep(25)
            }
            assertTrue("Finished composition must release deferred refresh", changed)
            ime(true)
            var expected = ""
            editor { expected = it.text.toString() }
            InstrumentationRegistry.getInstrumentation().runOnMainSync { old!!.setText("Retired editor must not write this") }
            scenario.recreate(); await("Edit a native draft")
            editor { assertEquals(expected, it.text.toString()) }
            scenario.moveToState(Lifecycle.State.CREATED); count(0); gone()
            scenario.moveToState(Lifecycle.State.RESUMED); await("Edit a native draft"); count(1)
            editor { assertEquals(expected, it.text.toString()) }
            // Programmatic closure works whether the native keyboard is open or hidden.
            scenario.onActivity { assertTrue(requireNotNull(NativeTestIds.find(it.window.decorView, "sheet-close-outside")).performClick()) }
            gone(); status(1); count(0)
        } finally { close(scenario) }
    }

    @Test fun realDragChangesCrystalDetentAndSaveKeepsTheSheetInteractive() {
        val scenario = launch()
        try {
            await("Native sheets"); appClick("sheet-reset")
            appClick("sheet-open-medium"); await("Edit a native draft")
            var dragY = 0; var endY = 0
            inside("sheet-title").check { view, error ->
                if (error != null) throw error
                val frame = requireNotNull(view.rootView.findViewById<FrameLayout>(com.google.android.material.R.id.design_bottom_sheet))
                val location = IntArray(2); frame.getLocationOnScreen(location)
                dragY = location[1] + (20 * view.resources.displayMetrics.density).toInt()
                endY = (80 * view.resources.displayMetrics.density).toInt()
            }
            assertTrue(device.swipe(device.displayWidth / 2, dragY, device.displayWidth / 2, endY, 40))
            // Gesture injection finishes before Material's settling animation.
            // Observe its real final state; never force a detent or swipe again.
            val settleDeadline = SystemClock.uptimeMillis() + 5000L
            var observedState = -1
            while (SystemClock.uptimeMillis() < settleDeadline && observedState != BottomSheetBehavior.STATE_EXPANDED) {
                inside("sheet-title").check { view, error ->
                    if (error != null) throw error
                    val frame = requireNotNull(view.rootView.findViewById<FrameLayout>(com.google.android.material.R.id.design_bottom_sheet))
                    observedState = BottomSheetBehavior.from(frame).state
                }
                if (observedState != BottomSheetBehavior.STATE_EXPANDED) SystemClock.sleep(25L)
            }
            assertEquals("The actual swipe must settle at the expanded detent", BottomSheetBehavior.STATE_EXPANDED, observedState)
            scenario.onActivity { CrystalBridge.requestRender() }
            SystemClock.sleep(600)
            scenario.onActivity {
                assertEquals("Current detent: large", (NativeSemantics.target(requireNotNull(NativeTestIds.find(it.window.decorView, "sheet-detent"))) as TextView).text.toString())
            }
            editor { it.setText("Saved from native sheet 雪 😀") }
            // The settled detent is not the end of motion: the expanded sheet
            // still lays out its content, and a slower emulator can move the
            // button between Espresso's coordinate lookup and its tap.
            awaitStable("sheet-save")
            inside("sheet-save").perform(scrollTo(), click())
            await("Saved: Saved from native sheet 雪 😀"); count(1)
            screenshot("sheet-saved-after-drag")
            awaitStable("sheet-done")
            inside("sheet-done").perform(scrollTo(), click()); gone(); status(1, 1)
        } finally { close(scenario) }
    }

    @Test fun structuralRemovalCompletesOnceAndCanSequenceAnotherNativeModal() {
        val scenario = launch()
        try {
            await("Native sheets"); appClick("sheet-reset")
            appClick("sheet-open"); await("Edit a native draft")
            scenario.onActivity { CrystalBridge.requestRender() }
            SystemClock.sleep(600); await("Edit a native draft"); count(1)
            scenario.onActivity {
                assertEquals("Dismissals: 0; saves: 0; behind: 0", (NativeSemantics.target(requireNotNull(NativeTestIds.find(it.window.decorView, "sheet-status"))) as TextView).text.toString())
            }
            var retired: View? = null
            inside("sheet-remove").check { view, error -> if (error != null) throw error; retired = view }
            inside("sheet-remove").perform(scrollTo(), click()); gone(); status(1); count(0)
            InstrumentationRegistry.getInstrumentation().runOnMainSync { retired!!.performClick() }
            status(1)
            appClick("sheet-open"); await("Edit a native draft")
            scenario.onActivity { requireNotNull(NativeTestIds.find(it.window.decorView, "sheet-rekey")).performClick() }
            gone(); status(2); count(0)
            appClick("sheet-open"); await("Edit a native draft")
            inside("sheet-chain").perform(scrollTo(), click())
            await("After the native sheet"); gone(); count(1)
            onView(NativeTestIds.withTestId("sheet-followup.action.0")).inRoot(isDialog()).perform(click())
            status(3); count(0)
        } finally { close(scenario) }
    }
}
