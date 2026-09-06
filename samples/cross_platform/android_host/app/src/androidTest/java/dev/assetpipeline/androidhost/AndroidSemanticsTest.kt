package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.CheckBox
import android.widget.EditText
import android.widget.RadioGroup
import android.widget.SeekBar
import android.widget.Spinner
import android.widget.TextView
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.google.android.material.textfield.TextInputLayout
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidSemanticsTest {
    private external fun renderProbeNative(context: Context): Int
    private fun launch(route: String = "semantics"): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, route)).also { awaitText("Native semantics") }
    }
    private fun awaitText(text: String) = assertTrue("Native semantics did not update", UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text(text)), 5000L))
    private fun view(activity: MainActivity, id: String) = requireNotNull(NativeTestIds.find(activity.findViewById(R.id.rendererMount), id))
    private fun editor(activity: MainActivity) = NativeSemantics.target(view(activity, "semantics-editor")) as EditText
    private fun counters(activity: MainActivity) = Regex("[0-9]+").findAll((view(activity, "semantics-status") as TextView).text).map { it.value.toInt() }.toList()
    private fun status(values: List<Int>) = "Actions: ${values[0]}; clicks: ${values[1]}; plain: ${values[2]}"
    private fun cleanup(scenario: ActivityScenario<MainActivity>) {
        scenario.close()
        InstrumentationRegistry.getInstrumentation().runOnMainSync { assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts()) }
    }
    private fun action(view: View, label: String) = view.createAccessibilityNodeInfo().actionList.single { it.label?.toString() == label }.id

    @Test fun nativeNodesKeepEditableCheckedRangeAndMaterialSemanticsSeparateFromIdentifiers() {
        val scenario = launch()
        try {
            scenario.onActivity { activity ->
                val button = view(activity, "automation-雪-button")
                val info = button.createAccessibilityNodeInfo()
                assertEquals("Save item", info.contentDescription.toString())
                assertEquals("Ready", info.stateDescription.toString())
                assertEquals("Saves the selected item", info.tooltipText.toString())
                assertTrue(info.isSelected); assertTrue(info.isClickable); assertTrue(info.isEnabled)
                assertEquals("automation-雪-button", info.extras.getString("dev.assetpipeline.test_id"))
                assertEquals("accessible-button-id", info.extras.getString("dev.assetpipeline.accessibility_identifier"))
                assertEquals("accessible-button-id", NativeSemantics.identifier(button))
                assertEquals(7, info.extras.getInt("dev.assetpipeline.tab_index"))
                assertTrue(view(activity, "semantics-heading").createAccessibilityNodeInfo().isHeading)
                assertNull(view(activity, "semantics-status").contentDescription)
                val field = editor(activity)
                val entered = field.text.toString()
                val layout = view(activity, "semantics-editor") as TextInputLayout
                layout.error = "Native Material error"
                val editable = field.createAccessibilityNodeInfo()
                assertNull(editable.contentDescription)
                assertEquals(entered, editable.text.toString())
                assertEquals("Account name", editable.hintText.toString())
                assertEquals("Native Material error", editable.error.toString())
                assertTrue(editable.isEditable)
                assertTrue(editable.actionList.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT })
                assertEquals("semantics-editor", editable.extras.getString("dev.assetpipeline.test_id"))
                val checkbox = view(activity, "semantics-checkbox") as CheckBox
                assertTrue(checkbox.createAccessibilityNodeInfo().isCheckable)
                assertTrue(checkbox.createAccessibilityNodeInfo().isChecked)
                assertTrue(checkbox.performAccessibilityAction(AccessibilityNodeInfo.ACTION_CLICK, null))
                assertFalse(checkbox.isChecked)
                val toggle = view(activity, "semantics-toggle").createAccessibilityNodeInfo()
                assertTrue(toggle.isCheckable); assertTrue(toggle.isChecked)
                val slider = view(activity, "semantics-slider") as SeekBar
                assertNotNull(slider.createAccessibilityNodeInfo().rangeInfo)
                assertTrue(slider.performAccessibilityAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SET_PROGRESS.id,
                    Bundle().apply { putFloat(AccessibilityNodeInfo.ACTION_ARGUMENT_PROGRESS_VALUE, 500f) }))
                assertEquals(500, slider.progress)
                val picker = NativeSemantics.target(view(activity, "semantics-picker")) as Spinner
                assertEquals(1, picker.selectedItemPosition)
                assertEquals("semantics-picker", picker.createAccessibilityNodeInfo().extras.getString("dev.assetpipeline.test_id"))
                val group = view(activity, "semantics-radio") as RadioGroup
                assertTrue(group.getChildAt(1).createAccessibilityNodeInfo().isChecked)
                assertFalse(view(activity, "semantics-disabled").createAccessibilityNodeInfo().isEnabled)
            }
        } finally { cleanup(scenario) }
    }

    @Test fun customActionUsesTheActualAccessibilityNodeAndRejectsOldHiddenDisabledAndBackgroundViews() {
        val scenario = launch()
        var old: View? = null
        var oldAction = 0
        var expected = emptyList<Int>()
        try {
            scenario.onActivity { activity ->
                expected = counters(activity).toMutableList().also { it[0]++ }
                old = view(activity, "automation-雪-button")
                oldAction = action(requireNotNull(old), "Archive 雪")
                val disabled = view(activity, "semantics-disabled")
                assertFalse(disabled.performAccessibilityAction(action(disabled, "Disabled archive"), null))
            }
            // This is the accessibility service's remote node/action path,
            // not a direct call to Crystal's callback registry.
            val root = requireNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.rootInActiveWindow)
            val node = root.findAccessibilityNodeInfosByText("Save item").single { it.contentDescription?.toString() == "Save item" }
            assertTrue(node.performAction(oldAction))
            awaitText(status(expected))
            scenario.onActivity { activity ->
                assertFalse(requireNotNull(old).isAttachedToWindow)
                assertFalse(requireNotNull(old).performAccessibilityAction(oldAction, null))
                val current = view(activity, "automation-雪-button")
                current.visibility = View.INVISIBLE
                assertFalse(current.performAccessibilityAction(action(current, "Archive 雪"), null))
                current.visibility = View.VISIBLE
                old = current; oldAction = action(current, "Archive 雪")
            }
            scenario.moveToState(Lifecycle.State.CREATED)
            scenario.onActivity { assertFalse(requireNotNull(old).performAccessibilityAction(oldAction, null)) }
            scenario.moveToState(Lifecycle.State.RESUMED)
            awaitText(status(expected))
        } finally { cleanup(scenario) }
    }

    @Test fun modifiedAndFocusedPlainShortcutsActivateOnceAndDoNotStealEditorText() {
        val scenario = launch()
        var expected = emptyList<Int>()
        try {
            scenario.onActivity { activity ->
                expected = counters(activity).toMutableList().also { it[1]++ }
                assertTrue(activity.dispatchKeyShortcutEvent(KeyEvent(0, 0, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_K, 0, KeyEvent.META_CTRL_ON)))
                assertTrue(activity.dispatchKeyShortcutEvent(KeyEvent(0, 0, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_K, 1, KeyEvent.META_CTRL_ON)))
                assertTrue(activity.dispatchKeyShortcutEvent(KeyEvent(0, 0, KeyEvent.ACTION_UP, KeyEvent.KEYCODE_K, 0, KeyEvent.META_CTRL_ON)))
            }
            awaitText(status(expected))
            scenario.onActivity { activity ->
                val field = editor(activity)
                assertTrue(NativeSemantics.requestFocus(field))
                val before = field.text.toString()
                activity.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_P))
                activity.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_P))
                assertEquals(before.length + 1, field.text.length)
                assertEquals(expected, counters(activity))
            }
            // Request a stable replacement after native editing and then
            // exercise a plain key only on its focused clickable control.
            InstrumentationRegistry.getInstrumentation().waitForIdleSync()
            scenario.onActivity { activity ->
                val plain = view(activity, "semantics-plain")
                assertTrue(NativeSemantics.requestFocus(plain))
                expected = expected.toMutableList().also { it[2]++ }
                assertTrue(activity.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_P)))
                assertTrue(activity.dispatchKeyEvent(KeyEvent(0, 0, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_P, 1)))
                assertTrue(activity.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_P)))
            }
            awaitText(status(expected))
        } finally { cleanup(scenario) }
    }

    @Test fun explicitFocusSkipsIneligibleViewsAndNonEditorFocusSurvivesBackgroundAndRecreation() {
        var scenario = launch("semantics-focus")
        try {
            scenario.onActivity { activity ->
                assertTrue(editor(activity).isFocused)
                assertFalse(view(activity, "semantics-skip").isFocusable)
                assertFalse(view(activity, "semantics-skip").requestFocus())
                assertFalse(view(activity, "semantics-disabled").isFocused)
                assertFalse(view(activity, "semantics-hidden").isFocused)
            }
        } finally { cleanup(scenario) }
        scenario = launch()
        try {
            scenario.onActivity { activity ->
                assertTrue(NativeSemantics.requestFocus(editor(activity)))
            }
            // Traversal belongs to ViewRootImpl, after Activity dispatch. Use
            // a real injected key so the platform gets that final fallback.
            assertTrue(UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).pressKeyCode(KeyEvent.KEYCODE_TAB))
            scenario.onActivity { activity ->
                assertTrue("Actual native Tab must skip the explicitly non-focusable button", view(activity, "semantics-plain").isFocused)
                val button = view(activity, "automation-雪-button")
                assertTrue(NativeSemantics.requestFocus(button))
                assertNotSame(view(activity, "semantics-skip"), button.focusSearch(View.FOCUS_FORWARD))
            }
            scenario.moveToState(Lifecycle.State.CREATED)
            scenario.moveToState(Lifecycle.State.RESUMED)
            awaitText("Native semantics")
            scenario.onActivity { assertTrue(view(it, "automation-雪-button").isFocused) }
            scenario.recreate()
            awaitText("Native semantics")
            scenario.onActivity { assertTrue(view(it, "automation-雪-button").isFocused) }
        } finally { cleanup(scenario) }
    }

    @Test fun invalidMetadataUnwindsAdoptedAndPendingCallbacksWithoutExposingInput() {
        val scenario = launch()
        try {
            scenario.onActivity { activity ->
                val baseline = CrystalBridge.debugCounts()
                repeat(100) {
                    try { renderProbeNative(activity); fail("Malformed semantics accepted") }
                    catch (expected: IllegalArgumentException) {
                        assertEquals("Invalid native semantics metadata", expected.message)
                        assertNull(expected.cause)
                    }
                    assertEquals(baseline, CrystalBridge.debugCounts())
                    assertEquals(HostSession.State.FOREGROUND, CrystalBridge.debugSessionState())
                }
                val native = View(activity)
                for (packet in listOf("private-input", JSONObject().put("version", "private-input").toString(), "private-input".repeat(4000))) {
                    try { NativeSemantics.configure(native, packet); fail("Malformed packet accepted") }
                    catch (expected: IllegalArgumentException) { assertFalse(expected.message!!.contains("private-input")); assertNull(expected.cause) }
                    assertNull(NativeSemantics.metadata(native))
                }
            }
        } finally { cleanup(scenario) }
    }
}
