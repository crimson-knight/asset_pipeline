package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Parcel
import android.os.SystemClock
import android.view.View
import android.widget.RadioGroup
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
class AndroidCompoundFocusTest {
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "compound-focus")).also { awaitHeading() }
    }
    private fun awaitHeading() = assertTrue(UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text("Compound focus")), 5000L))
    private fun view(activity: MainActivity, id: String) = requireNotNull(NativeTestIds.find(activity.findViewById(R.id.rendererMount), id))
    private fun group(activity: MainActivity, id: String = "compound-radio") = view(activity, id) as RadioGroup
    private fun close(scenario: ActivityScenario<MainActivity>) {
        scenario.close()
        InstrumentationRegistry.getInstrumentation().runOnMainSync { assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts()) }
    }
    private fun waitReplacement(scenario: ActivityScenario<MainActivity>, old: View, id: String = "compound-radio") {
        val end = SystemClock.uptimeMillis() + 5000
        while (SystemClock.uptimeMillis() < end) {
            var changed = false
            scenario.onActivity { changed = view(it, id) !== old }
            if (changed) { InstrumentationRegistry.getInstrumentation().waitForIdleSync(); return }
            SystemClock.sleep(25)
        }
        fail("Native compound was not replaced")
    }
    @Test fun exactUnselectedOptionFocusSurvivesRefreshBackgroundAndRecreationForBothNativeGroups() {
        val scenario = launch()
        try {
            for (id in listOf("compound-radio", "compound-segments")) {
                lateinit var old: View
                scenario.onActivity { activity ->
                    val choices = group(activity, id)
                    assertFalse(choices.isFocusable)
                    assertEquals(choices.getChildAt(0).id, choices.checkedRadioButtonId)
                    assertTrue(NativeSemantics.requestFocus(choices.getChildAt(1)))
                    assertEquals("Input focus must not silently select another option", choices.getChildAt(0).id, choices.checkedRadioButtonId)
                    old = choices
                    CrystalBridge.requestRender()
                }
                waitReplacement(scenario, old, id)
                scenario.onActivity { assertTrue(group(it, id).getChildAt(1).isFocused) }
                scenario.moveToState(Lifecycle.State.CREATED)
                scenario.moveToState(Lifecycle.State.RESUMED)
                awaitHeading()
                scenario.onActivity { assertTrue(group(it, id).getChildAt(1).isFocused) }
                scenario.recreate(); awaitHeading()
                scenario.onActivity { assertTrue(group(it, id).getChildAt(1).isFocused) }
            }
        } finally { close(scenario) }
    }
    @Test fun changedCatalogDropsOldOrdinalAndExplicitRequestsChooseTheCurrentSelectedOption() {
        val scenario = launch()
        try {
            lateinit var old: View
            scenario.onActivity { activity ->
                old = group(activity)
                assertTrue(NativeSemantics.requestFocus(group(activity).getChildAt(1)))
                assertTrue(view(activity, "compound-change").performClick())
            }
            waitReplacement(scenario, old)
            scenario.onActivity { activity ->
                assertFalse(group(activity).hasFocus())
                old = group(activity)
                assertTrue(NativeSemantics.requestFocus(group(activity).getChildAt(1)))
                assertTrue(view(activity, "compound-request").performClick())
            }
            waitReplacement(scenario, old)
            scenario.onActivity { activity ->
                assertTrue(group(activity).getChildAt(0).isFocused)
                for (id in listOf("compound-disabled", "compound-skip")) {
                    val choices = group(activity, id)
                    assertFalse(choices.hasFocus())
                    for (index in 0 until choices.childCount) {
                        val option = choices.getChildAt(index)
                        if (id == "compound-disabled") assertFalse(option.isEnabled) else assertFalse(option.isFocusable)
                        assertFalse(NativeSemantics.requestFocus(option))
                    }
                }
            }
        } finally { close(scenario) }
    }
    @Test fun serializedLocatorHasNoOptionCaptionsAndMalformedExtensionsFailClosed() {
        val scenario = launch()
        try {
            scenario.onActivity { activity ->
                assertTrue(NativeSemantics.requestFocus(group(activity).getChildAt(1)))
                val snapshot = NativeViewState.capture(activity.findViewById(R.id.rendererMount), "compound-focus")
                val entry = snapshot.entries.values.single { it.childFocus.present }
                assertEquals(1, entry.childFocus.index)
                val bundle = NativeViewState.toBundle(snapshot)
                assertEquals(snapshot, NativeViewState.fromBundle(bundle))
                val parcel = Parcel.obtain()
                val bytes = try { parcel.writeBundle(bundle); parcel.marshall() } finally { parcel.recycle() }
                fun contains(value: ByteArray) = (0..bytes.size - value.size).any { start -> value.indices.all { bytes[start + it] == value[it] } }
                for (caption in listOf("Choice one", "Choice 雪 two", "Choice three")) {
                    assertFalse(contains(caption.toByteArray(Charsets.UTF_8)))
                    assertFalse(contains(caption.toByteArray(Charsets.UTF_16LE)))
                }
                val old = NativeViewState.toBundle(snapshot)
                for (index in 0 until snapshot.entries.size) {
                    val child = requireNotNull(old.getBundle("entry$index"))
                    child.remove("child_index"); child.remove("child_signature")
                }
                assertTrue(requireNotNull(NativeViewState.fromBundle(old)).entries.values.all { !it.childFocus.present })
                for (bad in listOf<Any>("private-index", 256, -2)) {
                    val malformed = NativeViewState.toBundle(snapshot)
                    val child = requireNotNull(malformed.getBundle("entry0"))
                    if (bad is String) child.putString("child_index", bad) else child.putInt("child_index", bad as Int)
                    assertNull(NativeViewState.fromBundle(malformed))
                }
                val partial = NativeViewState.toBundle(snapshot)
                requireNotNull(partial.getBundle("entry0")).remove("child_signature")
                assertNull(NativeViewState.fromBundle(partial))
            }
        } finally { close(scenario) }
    }
}
