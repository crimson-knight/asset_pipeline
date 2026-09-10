package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.DatePicker
import android.widget.TimePicker
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Calendar
import java.util.TimeZone

/** Picker Tier A: native date and time pickers show Crystal values, honor bounds, report changes and survive recreation. */
@RunWith(AndroidJUnit4::class)
class AndroidPickersContractTest {
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "pickers-contract"))
    }
    private fun awaitText(text: String) = assertTrue("Native text did not update: $text",
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text(text)), 10000L))
    /** The native pickers are taller than the viewport; bring the Crystal echo label into view before waiting on it. */
    private fun awaitEcho(id: String, text: String) { onView(NativeTestIds.withTestId(id)).perform(scrollTo()); awaitText(text) }
    private fun view(activity: MainActivity, id: String): View = requireNotNull(NativeTestIds.find(activity.window.decorView, id)) { "missing $id" }
    private fun utcMillis(year: Int, month0: Int, day: Int): Long = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
        clear(); set(year, month0, day, 0, 0, 0)
    }.timeInMillis

    @Test fun datePickerShowsCrystalDateHonorsBoundsAndReportsChangesAcrossRecreation() {
        val scenario = launch()
        try {
            awaitEcho("pickers-date-echo", "Date: 2026-09-06; changes: 0")
            scenario.onActivity { activity ->
                val picker = view(activity, "pickers-date") as DatePicker
                assertEquals(2026, picker.year); assertEquals(8, picker.month); assertEquals(6, picker.dayOfMonth)
                assertEquals("minimum bound", utcMillis(2026, 0, 1), picker.minDate)
                assertEquals("maximum bound", utcMillis(2026, 11, 31), picker.maxDate)
            }
            scenario.onActivity { (view(it, "pickers-date") as DatePicker).updateDate(2026, 11, 25) }
            awaitEcho("pickers-date-echo", "Date: 2026-12-25; changes: 1")
            scenario.recreate()
            awaitEcho("pickers-date-echo", "Date: 2026-12-25; changes: 1")
            scenario.onActivity { activity ->
                val picker = view(activity, "pickers-date") as DatePicker
                assertEquals(2026, picker.year); assertEquals(11, picker.month); assertEquals(25, picker.dayOfMonth)
            }
        } finally { scenario.close() }
    }

    @Test fun timePickerShowsCrystalTimeInTwentyFourHourModeAndReportsChangesAcrossRecreation() {
        val scenario = launch()
        try {
            awaitEcho("pickers-time-echo", "Time: 09:30; changes: 0")
            scenario.onActivity { activity ->
                val picker = view(activity, "pickers-time") as TimePicker
                assertTrue("24-hour view", picker.is24HourView)
                assertEquals(9, picker.hour); assertEquals(30, picker.minute)
            }
            scenario.onActivity { (view(it, "pickers-time") as TimePicker).hour = 14 }
            awaitEcho("pickers-time-echo", "Time: 14:30; changes: 1")
            scenario.onActivity { (view(it, "pickers-time") as TimePicker).minute = 45 }
            awaitEcho("pickers-time-echo", "Time: 14:45; changes: 2")
            scenario.recreate()
            awaitEcho("pickers-time-echo", "Time: 14:45; changes: 2")
            scenario.onActivity { activity ->
                val picker = view(activity, "pickers-time") as TimePicker
                assertTrue(picker.is24HourView); assertEquals(14, picker.hour); assertEquals(45, picker.minute)
            }
        } finally { scenario.close() }
    }
}
