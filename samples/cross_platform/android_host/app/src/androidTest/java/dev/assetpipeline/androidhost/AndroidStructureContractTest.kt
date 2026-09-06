package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs
import kotlin.math.roundToInt

/** Structure Tier A: shapes with intrinsic sizes, grid rows, form sections and a disclosure header that toggles Crystal state. */
@RunWith(AndroidJUnit4::class)
class AndroidStructureContractTest {
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "structure-contract"))
    }
    private fun awaitText(text: String) = assertTrue("Native text did not update: $text",
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text(text)), 10000L))
    private fun view(activity: MainActivity, id: String): View = requireNotNull(NativeTestIds.find(activity.window.decorView, id)) { "missing $id" }
    private fun find(activity: MainActivity, id: String): View? = NativeTestIds.find(activity.window.decorView, id)
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
    private fun texts(view: View, into: MutableList<String> = ArrayList()): List<String> {
        if (view is TextView) into.add(view.text.toString())
        if (view is ViewGroup) for (index in 0 until view.childCount) texts(view.getChildAt(index), into)
        return into
    }
    private fun assertDp(label: String, expectedDp: Double, actualPx: Int, density: Float) {
        val expectedPx = (expectedDp * density).roundToInt()
        assertTrue("$label: expected ${expectedDp}dp (${expectedPx}px) but was ${actualPx}px", abs(expectedPx - actualPx) <= 1)
    }
    private fun headerDescription(activity: MainActivity) =
        (view(activity, "structure-disclosure") as ViewGroup).getChildAt(0).contentDescription.toString()

    @Test fun shapesRenderWithIntrinsicSizesFillsAndOutlines() {
        launch().use { scenario ->
            onView(NativeTestIds.withTestId("structure-rounded")).perform(scrollTo())
            waitUntil(scenario, "Shapes were not laid out") { view(it, "structure-rounded").width > 0 }
            scenario.onActivity { activity ->
                val density = activity.resources.displayMetrics.density
                val circle = view(activity, "structure-circle")
                assertDp("circle width", 48.0, circle.width, density); assertDp("circle height", 48.0, circle.height, density)
                assertTrue("circle clips to its outline", circle.clipToOutline)
                val capsule = view(activity, "structure-capsule")
                assertDp("capsule width", 120.0, capsule.width, density); assertDp("capsule height", 36.0, capsule.height, density)
                assertTrue("capsule clips to its outline", capsule.clipToOutline)
                val rectangle = view(activity, "structure-rectangle")
                assertDp("rectangle width", 90.0, rectangle.width, density); assertDp("rectangle height", 30.0, rectangle.height, density)
                val rounded = view(activity, "structure-rounded")
                assertDp("rounded width", 100.0, rounded.width, density); assertDp("rounded height", 40.0, rounded.height, density)
                assertTrue("rounded rectangle clips to its outline", rounded.clipToOutline)
                for (shape in listOf(circle, capsule, rectangle, rounded)) assertNotNull("shape fill", shape.background)
            }
        }
    }

    @Test fun gridRendersRowsAndFormRendersSectionsNatively() {
        launch().use { scenario ->
            onView(NativeTestIds.withTestId("structure-form")).perform(scrollTo())
            waitUntil(scenario, "Grid was not laid out") { view(it, "structure-grid").height > 0 }
            scenario.onActivity { activity ->
                val grid = view(activity, "structure-grid") as LinearLayout
                assertEquals(LinearLayout.VERTICAL, grid.orientation)
                assertEquals(2, grid.childCount)
                val rows = (0 until grid.childCount).map { grid.getChildAt(it) as LinearLayout }
                rows.forEach { row -> assertEquals(LinearLayout.HORIZONTAL, row.orientation); assertEquals(2, row.childCount) }
                assertEquals(listOf("A1", "A2"), texts(rows[0]))
                assertEquals(listOf("B1", "B2"), texts(rows[1]))
                assertTrue("cells sit side by side", rows[0].getChildAt(1).left > rows[0].getChildAt(0).left)
                assertTrue("rows stack vertically", rows[1].top > rows[0].top)
                val form = view(activity, "structure-form") as LinearLayout
                assertEquals(listOf("Contact", "Name", "Ada", "Email", "ada@example.invalid", "Footer note"), texts(form))
            }
        }
    }

    @Test fun disclosureHeaderTogglesCrystalStateAndSurvivesRecreation() {
        val scenario = launch()
        try {
            onView(NativeTestIds.withTestId("structure-disclosure")).perform(scrollTo())
            awaitText("Expanded: false; toggles: 0")
            scenario.onActivity { activity ->
                assertNull("collapsed content is not rendered", find(activity, "structure-detail"))
                assertEquals("Details, collapsed", headerDescription(activity))
            }
            onView(withText("Details")).perform(click())
            awaitText("Expanded: true; toggles: 1")
            waitUntil(scenario, "Detail did not appear") { find(it, "structure-detail") != null }
            scenario.onActivity { assertEquals("Details, expanded", headerDescription(it)) }
            scenario.recreate()
            awaitText("Expanded: true; toggles: 1")
            waitUntil(scenario, "Detail did not survive recreation") { find(it, "structure-detail") != null }
            waitUntil(scenario, "Session did not return to the foreground") { CrystalBridge.debugSessionState() == HostSession.State.FOREGROUND }
            onView(NativeTestIds.withTestId("structure-disclosure")).perform(scrollTo())
            onView(withText("Details")).perform(click())
            awaitText("Expanded: false; toggles: 2")
            waitUntil(scenario, "Detail did not collapse") { find(it, "structure-detail") == null }
        } finally { scenario.close() }
    }
}
