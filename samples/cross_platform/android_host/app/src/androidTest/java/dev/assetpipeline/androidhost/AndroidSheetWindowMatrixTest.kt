package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Rect
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.TextView
import android.view.inputmethod.InputMethodManager
import android.view.inputmethod.EditorInfo
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
import androidx.test.uiautomator.UiDevice
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AndroidSheetWindowMatrixTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val device get() = UiDevice.getInstance(instrumentation)
    private fun main(block: () -> Unit) = instrumentation.runOnMainSync(block)
    private fun waitFor(message: String, condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 5000
        while (SystemClock.uptimeMillis() < deadline) {
            var result = false
            main { result = condition() }
            if (result) return
            SystemClock.sleep(25)
        }
        fail(message)
    }
    private fun inside(id: String) = onView(NativeTestIds.withTestId(id)).inRoot(isDialog())
    private data class Parts(val owner: View, val editor: EditText, val viewport: NestedScrollView, val frame: FrameLayout)
    private fun parts(): Parts {
        var result: Parts? = null
        inside("sheet-draft").check { view, error ->
            if (error != null) throw error
            var parent = view.parent
            while (parent is View && parent !is NestedScrollView) parent = parent.parent
            result = Parts(view, NativeSemantics.target(view) as EditText, parent as NestedScrollView,
                requireNotNull(view.rootView.findViewById(com.google.android.material.R.id.design_bottom_sheet)))
        }
        return requireNotNull(result)
    }
    private fun screenshot(name: String) {
        val folder = requireNotNull(instrumentation.targetContext.getExternalFilesDir("sheet-window-proof")).apply { mkdirs() }
        assertTrue(device.takeScreenshot(File(folder, "$name.png")))
    }
    private fun configured(profile: WindowMatrixActivity.Profile, landscape: Boolean,
        block: (ActivityScenario<WindowMatrixActivity>) -> Unit) {
        val rotation = device.displayRotation
        val previous = WindowMatrixActivity.profile
        WindowMatrixActivity.profile = profile
        var opened: ActivityScenario<WindowMatrixActivity>? = null
        var requested = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        try {
            val scenario = ActivityScenario.launch<WindowMatrixActivity>(Intent(
                ApplicationProvider.getApplicationContext<Context>(), WindowMatrixActivity::class.java)
                .putExtra(MainActivity.EXTRA_APP_SLUG, "sheets-contract")
                .putExtra(MainActivity.EXTRA_STUDY_APPEARANCE, if (profile.language == "ar") "dark" else "light"))
            opened = scenario
            scenario.onActivity {
                requested = it.requestedOrientation
                it.requestedOrientation = if (landscape) ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE else ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            }
            waitFor("Matrix Activity did not reach requested orientation") { (device.displayWidth > device.displayHeight) == landscape }
            block(scenario)
        } finally {
            try {
                opened?.onActivity {
                    if (CrystalBridge.debugSessionState() == HostSession.State.FOREGROUND && CrystalBridge.debugDialogCount() > 0)
                        NativeTestIds.find(it.window.decorView, "sheet-close-outside")?.performClick()
                    it.requestedOrientation = requested
                }
            } finally {
                try { opened?.close() } finally { WindowMatrixActivity.profile = previous }
            }
            waitFor("Matrix orientation override was not released") { device.displayRotation == rotation }
            main {
                assertEquals(0, CrystalBridge.debugDialogCount())
                assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
            }
        }
    }
    private fun fullyVisible(view: View) {
        val bounds = Rect()
        assertTrue("Native control must be visible", view.getGlobalVisibleRect(bounds))
        assertEquals("Entire control height must be reachable", view.height, bounds.height())
        assertEquals("Entire control width must be reachable", view.width, bounds.width())
    }
    private fun keyboardEditorVisible(shown: Parts) {
        val info = EditorInfo()
        assertNotNull(shown.editor.onCreateInputConnection(info))
        assertEquals(EditorInfo.IME_FLAG_NO_FULLSCREEN, info.imeOptions and EditorInfo.IME_FLAG_NO_FULLSCREEN)
        assertEquals(EditorInfo.IME_ACTION_DONE, info.imeOptions and EditorInfo.IME_MASK_ACTION)
        assertFalse("Sheet editing must not be replaced by fullscreen IME extraction", (shown.editor.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager).isFullscreenMode)
        fullyVisible(shown.editor); assertTrue(shown.editor.isFocused)
        val insets = requireNotNull(ViewCompat.getRootWindowInsets(shown.frame))
        assertTrue(insets.isVisible(WindowInsetsCompat.Type.ime()))
        val origin = IntArray(2); shown.frame.rootView.getLocationOnScreen(origin)
        val keyboardTop = origin[1] + shown.frame.rootView.height - insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
        val editor = IntArray(2); shown.editor.getLocationOnScreen(editor)
        assertTrue("Complete editor must be above the keyboard", editor[1] + shown.editor.height <= keyboardTop)
        val shell = shown.viewport.parent as ViewGroup
        val handle = (0 until shell.childCount).map { shell.getChildAt(it) }
            .filterIsInstance<com.google.android.material.bottomsheet.BottomSheetDragHandleView>().single()
        // Keyboard height and native text scaling vary by Android/IME version.
        // A landscape/font profile alone does not establish a cramped window.
        // Measure this fixture's complete controls and actual remaining body;
        // do not call the production policy to derive its own expected result.
        val controlHeight = listOf("sheet-draft", "sheet-save", "sheet-done",
            "sheet-presenter-done", "sheet-remove", "sheet-chain").maxOf { id ->
            requireNotNull(NativeTestIds.find(shown.viewport, id)).height
        }
        val minimumViewport = maxOf((48 * shown.editor.resources.displayMetrics.density).toInt(), controlHeight)
        val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
        val imeHeight = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
        val availableBody = maxOf(0, (shown.frame.parent as View).height - bars.top - maxOf(bars.bottom, imeHeight))
        val cramped = minimumViewport.toLong() + handle.measuredHeight > availableBody
        instrumentation.sendStatus(0, Bundle().apply {
            putString("sheet_window_keyboard", "viewport=${shown.viewport.height} editorTop=${editor[1]} editorHeight=${shown.editor.height} keyboardTop=$keyboardTop rootHeight=${shown.frame.rootView.height} displayHeight=${device.displayHeight} orientation=${shown.editor.resources.configuration.orientation} handle=${handle.visibility} availableBody=$availableBody minimumViewport=$minimumViewport handleHeight=${handle.measuredHeight}")
        })
        assertEquals("Cramped keyboard must temporarily prioritize controls over the handle", if (cramped) View.GONE else View.VISIBLE, handle.visibility)
        assertTrue("Viewport must fit a complete control when the window allows it",
            shown.viewport.height >= minOf(minimumViewport, availableBody))
    }
    private fun awaitKeyboard(shown: Parts, message: String) {
        var stableSince = 0L
        waitFor(message) {
            val root = shown.frame.rootView
            val ready = shown.frame.isAttachedToWindow && shown.editor.hasWindowFocus() &&
                root.width == device.displayWidth && root.height == device.displayHeight &&
                !shown.viewport.isLayoutRequested && ViewCompat.getRootWindowInsets(shown.frame)?.isVisible(WindowInsetsCompat.Type.ime()) == true &&
                (shown.editor.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager).isActive(shown.editor)
            if (!ready) stableSince = 0L
            else if (stableSince == 0L) stableSince = SystemClock.uptimeMillis()
            ready && SystemClock.uptimeMillis() - stableSince >= 250L
        }
    }
    @Test fun largeTextAndRtlKeepNativeControlsReadableAndReachable() {
        for (language in listOf("en", "ar")) for (landscape in listOf(false, true)) {
            configured(WindowMatrixActivity.Profile(2f, language), landscape) { scenario ->
                onView(NativeTestIds.withTestId("sheet-open-small-only")).perform(scrollTo(), click())
                var shown = parts()
                main {
                    assertEquals(2f, shown.owner.resources.configuration.fontScale, 0.001f)
                    assertEquals(language, shown.owner.resources.configuration.locales[0].language)
                    assertEquals(if (language == "ar") View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR, shown.owner.layoutDirection)
                    assertTrue("Large-text viewport must fit its complete input", shown.viewport.height >= shown.owner.height)
                    assertTrue("Test must actually enlarge the native text", shown.editor.textSize > 24 * shown.editor.resources.displayMetrics.density)
                    instrumentation.sendStatus(0, Bundle().apply {
                        putString("sheet_window_profile", "font=2 language=$language landscape=$landscape frame=${shown.frame.height} viewport=${shown.viewport.height} editor=${shown.editor.height} textPixels=${shown.editor.textSize}")
                    })
                }
                inside("sheet-title").perform(scrollTo()).check { view, error ->
                    if (error != null) throw error
                    fullyVisible(view)
                    val text = NativeSemantics.target(view) as TextView
                    for (line in 0 until text.layout.lineCount) assertEquals(0, text.layout.getEllipsisCount(line))
                }
                inside("sheet-draft").perform(scrollTo())
                val draft = if (language == "ar") "ملاحظة 雪 😀 e\u0301" else "Large text 雪 😀 e\u0301"
                main { fullyVisible(shown.editor); shown.editor.setText(draft) }
                screenshot("large-$language-$landscape-editor")
                val previous = shown.frame
                inside("sheet-save").perform(scrollTo(), click())
                waitFor("Save must refresh the native sheet") { !previous.isAttachedToWindow }
                shown = parts()
                inside("sheet-saved").perform(scrollTo()).check { view, error ->
                    if (error != null) throw error
                    assertEquals("Saved: $draft", (NativeSemantics.target(view) as TextView).text.toString())
                }
                scenario.onActivity {
                    assertEquals("Current detent: small", (NativeSemantics.target(requireNotNull(NativeTestIds.find(it.window.decorView, "sheet-detent"))) as TextView).text.toString())
                }
                inside("sheet-chain").perform(scrollTo(), click())
                onView(NativeTestIds.withTestId("sheet-followup.action.0")).inRoot(isDialog()).perform(click())
            }
        }
    }
    @Test fun landscapeKeyboardKeepsTheNativeSheetEditorUsableThroughRecreation() = landscapeKeyboard(WindowMatrixActivity.Profile())
    @Test fun largeLandscapeKeyboardKeepsTheNativeSheetEditorUsableThroughRecreation() = landscapeKeyboard(WindowMatrixActivity.Profile(2f))
    @Test fun rtlLargeLandscapeKeyboardKeepsTheNativeSheetEditorUsableThroughRecreation() = landscapeKeyboard(WindowMatrixActivity.Profile(2f, "ar"))
    private fun landscapeKeyboard(profile: WindowMatrixActivity.Profile) {
        configured(profile, true) { scenario ->
            onView(NativeTestIds.withTestId("sheet-open-small-only")).perform(scrollTo(), click())
            inside("sheet-draft").perform(scrollTo())
            var shown = parts()
            var x = 0; var y = 0
            main {
                fullyVisible(shown.editor)
                val bounds = Rect(); shown.editor.getGlobalVisibleRect(bounds); x = bounds.centerX(); y = bounds.centerY()
            }
            assertTrue(device.click(x, y))
            awaitKeyboard(shown, "Landscape keyboard did not become visible")
            device.waitForIdle(1000)
            inside("sheet-draft").check { _, error -> if (error != null) throw error }
            screenshot("landscape-keyboard-${profile.fontScale}-${profile.language}")
            main {
                keyboardEditorVisible(shown)
                shown.editor.setText("Landscape 雪 😀 e\u0301"); shown.editor.setSelection(2, 7)
            }
            scenario.recreate(); shown = parts()
            awaitKeyboard(shown, "Landscape keyboard did not restore")
            device.waitForIdle(1000)
            inside("sheet-draft").check { _, error -> if (error != null) throw error }
            main {
                keyboardEditorVisible(shown)
                assertEquals("Landscape 雪 😀 e\u0301", shown.editor.text.toString())
                assertEquals(2, shown.editor.selectionStart); assertEquals(7, shown.editor.selectionEnd)
            }
            screenshot("landscape-keyboard-restored-${profile.fontScale}-${profile.language}")
            for (orientation in listOf(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT, ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)) {
                val previous = shown.frame
                scenario.onActivity { it.requestedOrientation = orientation }
                waitFor("Rotation did not recreate the sheet") {
                    !previous.isAttachedToWindow && (device.displayWidth > device.displayHeight) == (orientation == ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
                }
                shown = parts()
                awaitKeyboard(shown, "Rotated keyboard did not restore")
                device.waitForIdle(1000)
                inside("sheet-draft").check { _, error -> if (error != null) throw error }
                main {
                    keyboardEditorVisible(shown)
                    assertEquals(profile.fontScale, shown.editor.resources.configuration.fontScale, 0.001f)
                    assertEquals(if (profile.language == "ar") View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR, shown.owner.layoutDirection)
                    assertEquals("Landscape 雪 😀 e\u0301", shown.editor.text.toString())
                    assertEquals(2, shown.editor.selectionStart); assertEquals(7, shown.editor.selectionEnd)
                }
            }
            assertTrue(device.pressBack())
            try {
                waitFor("Back must hide the keyboard without closing the sheet") {
                    shown.frame.isAttachedToWindow && ViewCompat.getRootWindowInsets(shown.frame)?.isVisible(WindowInsetsCompat.Type.ime()) == false
                }
            } catch (error: AssertionError) {
                screenshot("keyboard-back-failure-${profile.fontScale}-${profile.language}")
                main { instrumentation.sendStatus(0, Bundle().apply {
                    putString("sheet_back_failure", "attached=${shown.frame.isAttachedToWindow} focused=${shown.editor.isFocused} ime=${ViewCompat.getRootWindowInsets(shown.frame)?.isVisible(WindowInsetsCompat.Type.ime())} viewport=${shown.viewport.height} frame=${shown.frame.height} dialogs=${CrystalBridge.debugDialogCount()}")
                }) }
                throw error
            }
            inside("sheet-draft").check { _, error -> if (error != null) throw error }
            main {
                val shell = shown.viewport.parent as ViewGroup
                assertTrue((0 until shell.childCount).map { shell.getChildAt(it) }
                    .filterIsInstance<com.google.android.material.bottomsheet.BottomSheetDragHandleView>().single().isShown)
                assertTrue(shown.viewport.height >= shown.owner.height)
            }
            screenshot("landscape-keyboard-closed-${profile.fontScale}-${profile.language}")
            inside("sheet-chain").perform(scrollTo(), click())
            onView(NativeTestIds.withTestId("sheet-followup.action.0")).inRoot(isDialog()).perform(click())
        }
    }
    @Test fun smallOnlyLandscapeViewportFitsAnEntireEditableControl() {
        val originalRotation = device.displayRotation
        val scenario = ActivityScenario.launch<MainActivity>(Intent(
            ApplicationProvider.getApplicationContext<Context>(), MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_APP_SLUG, "sheets-contract")
            .putExtra(MainActivity.EXTRA_STUDY_APPEARANCE, "light"))
        var originalOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        try {
            scenario.onActivity {
                originalOrientation = it.requestedOrientation
                it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            }
            waitFor("Task Activity did not rotate to landscape") { device.displayWidth > device.displayHeight }
            onView(NativeTestIds.withTestId("sheet-open-small-only")).perform(scrollTo(), click())
            val shown = parts()
            screenshot("small-landscape-before-editor-scroll")
            main {
                assertEquals(Configuration.ORIENTATION_LANDSCAPE, shown.owner.resources.configuration.orientation)
                val visible = Rect()
                assertTrue(shown.viewport.getGlobalVisibleRect(visible))
                instrumentation.sendStatus(0, Bundle().apply {
                    putString("sheet_window_geometry", "landscape frame=${shown.frame.height} viewport=${shown.viewport.height} control=${shown.owner.height} editor=${shown.editor.height}")
                })
                assertEquals(shown.viewport.height, visible.height())
                assertTrue("Landscape viewport ${shown.viewport.height} must fit the complete ${shown.owner.height}-pixel editor control",
                    shown.viewport.height >= shown.owner.height)
            }
            inside("sheet-draft").perform(scrollTo())
            main {
                val editor = Rect()
                assertTrue(shown.editor.getGlobalVisibleRect(editor)); assertEquals(shown.editor.height, editor.height())
            }
            inside("sheet-chain").perform(scrollTo(), click())
            onView(NativeTestIds.withTestId("sheet-followup.action.0")).inRoot(isDialog()).perform(click())
        } finally {
            scenario.onActivity {
                if (CrystalBridge.debugSessionState() == HostSession.State.FOREGROUND && CrystalBridge.debugDialogCount() > 0)
                    NativeTestIds.find(it.window.decorView, "sheet-close-outside")?.performClick()
                it.requestedOrientation = originalOrientation
            }
            scenario.close()
            waitFor("Activity orientation override was not released") { device.displayRotation == originalRotation }
            main {
                assertEquals(0, CrystalBridge.debugDialogCount())
                assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
            }
        }
    }
}
