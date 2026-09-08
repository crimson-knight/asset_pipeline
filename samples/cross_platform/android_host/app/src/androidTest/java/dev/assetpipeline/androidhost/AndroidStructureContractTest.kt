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
import androidx.test.espresso.NoMatchingViewException
import androidx.test.espresso.PerformException
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed

/** Structure Tier A: shapes with intrinsic sizes, grid rows, form sections and a disclosure header that toggles Crystal state. */
@RunWith(AndroidJUnit4::class)
class AndroidStructureContractTest {
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "structure-contract"))
    }
    // Scroll the text into view while waiting: UiAutomator only sees what is
    // on screen, and on a phone whose shorter display leaves this fixture's
    // echo labels below the fold the text exists without being visible.
    private fun awaitText(text: String) {
        val deadline = SystemClock.uptimeMillis() + 10000L
        while (true) {
            try {
                onView(withText(text)).perform(scrollTo()).check(matches(isDisplayed()))
                return
            } catch (missing: NoMatchingViewException) {
            } catch (undisplayed: PerformException) {
            } catch (undisplayed: AssertionError) {
            }
            if (SystemClock.uptimeMillis() >= deadline) throw AssertionError("Native text did not update: $text")
            SystemClock.sleep(50L)
        }
    }
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
    // A tap is computed from a row's screen position and delivered a moment
    // later. Two things move the rows after Espresso's scroll-into-view
    // returns: the sample host's plain ScrollView scrolls smoothly for about a
    // quarter second, and the host's first pre-draw pass after a render scrolls
    // the container to the top when no saved state matches the screen. On a
    // software-rendered runner a few polls can read the same position between
    // two slow frames while either is still in flight, which is how CI runs 25,
    // 26 and 29 delivered this test's tap one row off. Wait until the current
    // render has been presented (its pre-draw pass completed), then until the
    // row is drawn, nothing is waiting for layout, and the row's position and
    // the container's scroll offset have held for longer than the scroll
    // animation.
    private fun awaitPresented(scenario: ActivityScenario<MainActivity>, atLeast: Int) {
        waitUntil(scenario, "The render was not presented") { it.debugPresentedRenders() >= atLeast }
    }
    private fun presented(scenario: ActivityScenario<MainActivity>): Int {
        var value = 0
        scenario.onActivity { value = it.debugPresentedRenders() }
        return value
    }
    private fun awaitSettledRow(scenario: ActivityScenario<MainActivity>, text: String, presentedAtLeast: Int) {
        awaitPresented(scenario, presentedAtLeast)
        var last: Triple<Int, Int, Int>? = null
        var stableSince = 0L
        waitUntil(scenario, "Row did not settle before its tap: $text") { activity ->
            val list = view(activity, "structure-list") as LinearLayout
            val row = (0 until list.childCount).map { list.getChildAt(it) }.firstOrNull { texts(it) == listOf(text) }
                ?: return@waitUntil false
            val location = IntArray(2).also { row.getLocationOnScreen(it) }
            val container = activity.findViewById<View>(R.id.hostViewport)
            val state = Triple(location[0], location[1], container.scrollY)
            val quiet = !row.isDirty && !list.isLayoutRequested && !activity.window.decorView.isLayoutRequested
            val now = SystemClock.uptimeMillis()
            if (!quiet || state != last) { last = state; stableSince = now; return@waitUntil false }
            now - stableSince >= 400L
        }
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

    @Test fun listRowsAreSectionedSeparatedAndTappableWithCrystalIndexes() {
        val scenario = launch()
        try {
            awaitPresented(scenario, 1)
            onView(NativeTestIds.withTestId("structure-list-echo")).perform(scrollTo())
            awaitText("Row: -1; section: none; taps: 0")
            scenario.onActivity { activity ->
                val list = view(activity, "structure-list") as LinearLayout
                assertEquals(listOf("Fruits", "Apple", "Banana", "Vegetables", "Carrot"), texts(list))
                // header, row, separator, row, header, row
                assertEquals(6, list.childCount)
                val separator = list.getChildAt(2)
                assertTrue("separator is a plain thin view", separator !is ViewGroup && separator !is TextView && separator.height in 1..4)
                assertTrue("rows are clickable containers", list.getChildAt(1).isClickable && list.getChildAt(5).isClickable)
            }
            val presentedBeforeBanana = presented(scenario)
            awaitSettledRow(scenario, "Banana", presentedBeforeBanana)
            onView(withText("Banana")).perform(click())
            awaitText("Row: 1; section: 0,1; taps: 1")
            // The tap's refresh replaced the tree; wait for that render's own pass.
            awaitSettledRow(scenario, "Carrot", presentedBeforeBanana + 1)
            onView(withText("Carrot")).perform(click())
            awaitText("Row: 2; section: 1,0; taps: 2")
            scenario.recreate()
            onView(NativeTestIds.withTestId("structure-list-echo")).perform(scrollTo())
            awaitText("Row: 2; section: 1,0; taps: 2")
        } finally { scenario.close() }
    }
}
