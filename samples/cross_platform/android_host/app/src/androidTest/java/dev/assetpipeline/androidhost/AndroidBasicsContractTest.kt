package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.text.InputType
import android.text.method.PasswordTransformationMethod
import android.view.View
import android.widget.EditText
import android.widget.ImageButton
import android.widget.ToggleButton
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.replaceText
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.espresso.matcher.ViewMatchers.isAssignableFrom
import androidx.test.espresso.matcher.ViewMatchers.isDescendantOfA
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.google.android.material.progressindicator.CircularProgressIndicator
import com.google.android.material.progressindicator.LinearProgressIndicator
import org.hamcrest.Matchers.allOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/** Core Tier A basics: secure field, text area, progress views, activity indicator, divider, icon button. */
@RunWith(AndroidJUnit4::class)
class AndroidBasicsContractTest {
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "basics-contract"))
    }
    private fun awaitText(text: String) = assertTrue("Native text did not update: $text",
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text(text)), 10000L))
    private fun view(activity: MainActivity, id: String): View = requireNotNull(NativeTestIds.find(activity.window.decorView, id)) { "missing $id" }
    private fun editor(activity: MainActivity, id: String): EditText = NativeSemantics.target(view(activity, id)) as EditText
    /**
     * The host defers a non-user refresh while the focused editor has a
     * composing span, and the keyboard marks the tapped word composing after
     * focus. End composition the way a real submit does, then let the
     * refresh land before observing Crystal-owned labels.
     */
    private fun endComposition(scenario: ActivityScenario<MainActivity>, id: String) {
        scenario.onActivity { activity ->
            val field = editor(activity, id)
            field.onCreateInputConnection(android.view.inputmethod.EditorInfo())?.finishComposingText()
            field.clearFocus()
        }
        // Text changes update Crystal state without rebuilding the tree; the
        // echo labels show on the next render, as after any user action.
        scenario.onActivity { CrystalBridge.requestRender() }
        SystemClock.sleep(600L)
    }
    private fun scrollToId(id: String) = onView(NativeTestIds.withTestId(id)).perform(scrollTo())
    private fun ratio(bar: android.widget.ProgressBar) = bar.progress.toDouble() / bar.max.toDouble()
    private fun waitUntil(scenario: ActivityScenario<MainActivity>, message: String, condition: (MainActivity) -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 5000L
        while (SystemClock.uptimeMillis() < deadline) {
            var ok = false
            scenario.onActivity { ok = condition(it) }
            if (ok) return
            SystemClock.sleep(50L)
        }
        fail(message)
    }

    @Test fun secureFieldMasksInputAndKeepsItsValueInCrystalAcrossRecreation() {
        val scenario = launch()
        try {
            awaitText("Native basics")
            scenario.onActivity { activity ->
                val field = editor(activity, "basics-secret")
                assertTrue("Secure field must mask input", field.transformationMethod is PasswordTransformationMethod)
                val masked = field.inputType and InputType.TYPE_TEXT_VARIATION_PASSWORD != 0 ||
                    field.inputType and InputType.TYPE_NUMBER_VARIATION_PASSWORD != 0
                assertTrue("Secure field must declare a password input type", masked)
            }
            onView(allOf(isAssignableFrom(EditText::class.java), isDescendantOfA(NativeTestIds.withTestId("basics-secret")))).perform(scrollTo(), replaceText("1234"))
            endComposition(scenario, "basics-secret")
            scrollToId("basics-secret-echo"); awaitText("Secret length: 4")
            scenario.recreate()
            scrollToId("basics-secret-echo"); awaitText("Secret length: 4")
            scenario.onActivity { activity ->
                val field = editor(activity, "basics-secret")
                assertEquals("Crystal owns the secret across recreation", "1234", field.text.toString())
                assertTrue(field.transformationMethod is PasswordTransformationMethod)
            }
        } finally { scenario.close() }
    }

    @Test fun textAreaIsMultilineAndReportsLinesToCrystal() {
        val scenario = launch()
        try {
            awaitText("Native basics")
            scenario.onActivity { activity ->
                val notes = editor(activity, "basics-notes")
                assertTrue("Text area must be multi-line", notes.inputType and InputType.TYPE_TEXT_FLAG_MULTI_LINE != 0)
                assertEquals("Line one\nLine two", notes.text.toString())
            }
            scrollToId("basics-notes-echo"); awaitText("Lines: 2")
            onView(allOf(isAssignableFrom(EditText::class.java), isDescendantOfA(NativeTestIds.withTestId("basics-notes")))).perform(scrollTo(), replaceText("a\nb\nc"))
            endComposition(scenario, "basics-notes")
            scrollToId("basics-notes-echo"); awaitText("Lines: 3")
        } finally { scenario.close() }
    }

    @Test fun progressViewsRenderMaterialIndicatorsWithRealValues() {
        val scenario = launch()
        try {
            awaitText("Native basics")
            scenario.onActivity { activity ->
                val linear = view(activity, "basics-progress") as LinearProgressIndicator
                assertFalse("Determinate progress must not be indeterminate", linear.isIndeterminate)
                assertEquals(0.35, ratio(linear), 0.001)
                val busy = view(activity, "basics-progress-indeterminate") as LinearProgressIndicator
                assertTrue("Nil value must render indeterminate", busy.isIndeterminate)
                val circular = view(activity, "basics-progress-circular") as CircularProgressIndicator
                assertFalse(circular.isIndeterminate); assertEquals(0.5, ratio(circular), 0.001)
                val spinner = view(activity, "basics-spinner") as CircularProgressIndicator
                assertTrue(spinner.isIndeterminate); assertEquals(View.VISIBLE, spinner.visibility)
                assertEquals("A paused indicator is invisible, not gone", View.INVISIBLE, view(activity, "basics-spinner-paused").visibility)
            }
            onView(NativeTestIds.withTestId("basics-advance")).perform(scrollTo(), click())
            waitUntil(scenario, "Progress did not advance to 0.75") { activity ->
                (NativeTestIds.find(activity.window.decorView, "basics-progress") as? LinearProgressIndicator)?.let { Math.abs(ratio(it) - 0.75) < 0.001 } == true
            }
        } finally { scenario.close() }
    }

    @Test fun dividerAndIconButtonRenderNativelyAndTheIconCallsBack() {
        val scenario = launch()
        try {
            awaitText("Native basics")
            scenario.onActivity { activity ->
                val density = activity.resources.displayMetrics.density
                val divider = view(activity, "basics-divider")
                assertEquals("Divider height follows its logical thickness", Math.round(2f * density), divider.height)
                assertTrue("Divider fills the row", divider.width > 0)
                val icon = view(activity, "basics-icon") as ImageButton
                assertNotNull("Icon button must resolve its catalog drawable", icon.drawable)
                assertEquals("Spoken label comes from accessibility_label", "Add item", icon.contentDescription?.toString())
            }
            scrollToId("basics-icon-echo"); awaitText("Icon taps: 0")
            onView(NativeTestIds.withTestId("basics-icon")).perform(scrollTo(), click())
            scrollToId("basics-icon-echo"); awaitText("Icon taps: 1")
        } finally { scenario.close() }
    }

    @Test fun toggleButtonKeepsItsLabelAndReportsStateToCrystal() {
        val scenario = launch()
        try {
            awaitText("Native basics")
            scenario.onActivity { activity ->
                val toggle = view(activity, "basics-toggle-button") as ToggleButton
                assertEquals("Toggle button keeps its label in both states", "Bold", toggle.text.toString())
                assertFalse(toggle.isChecked)
            }
            scrollToId("basics-toggle-echo"); awaitText("Bold: false")
            onView(NativeTestIds.withTestId("basics-toggle-button")).perform(scrollTo(), click())
            scrollToId("basics-toggle-echo"); awaitText("Bold: true")
            scenario.onActivity { activity ->
                val toggle = view(activity, "basics-toggle-button") as ToggleButton
                assertTrue(toggle.isChecked); assertEquals("Bold", toggle.text.toString())
            }
        } finally { scenario.close() }
    }

    @Test fun linkButtonCallsBackToCrystalOrOpensItsUrl() {
        val scenario = launch()
        try {
            awaitText("Native basics")
            scrollToId("basics-link-echo"); awaitText("Link taps: 0")
            onView(NativeTestIds.withTestId("basics-link")).perform(scrollTo(), click())
            scrollToId("basics-link-echo"); awaitText("Link taps: 1")
            scenario.onActivity { activity ->
                val browser = view(activity, "basics-link-browser")
                assertTrue("A link without a Crystal handler must open its URL on tap", browser.hasOnClickListeners())
                assertEquals("Open site", (browser as android.widget.Button).text.toString())
            }
        } finally { scenario.close() }
    }
}
