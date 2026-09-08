package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.SystemClock
import android.util.Log
import android.view.ContextThemeWrapper
import android.view.View
import android.view.ViewGroup
import android.widget.HorizontalScrollView
import android.widget.ScrollView
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.*
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.*
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.roundToInt
import androidx.test.espresso.action.GeneralLocation
import androidx.test.espresso.action.GeneralSwipeAction
import androidx.test.espresso.action.Press
import androidx.test.espresso.action.Swipe

@RunWith(AndroidJUnit4::class)
class AndroidLayoutContractTest {
    private fun find(root: View, id: String): View {
        fun visit(view: View): View? {
            if (NativeSemantics.testId(view) == id) return view
            if (view is ViewGroup) for (i in 0 until view.childCount) visit(view.getChildAt(i))?.let { return it }
            return null
        }
        return requireNotNull(visit(root)) { "Missing layout view $id" }
    }
    private fun launch(route: String): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, route))
    }

    @Test fun measuredConstraintsStacksSpacersAndScrollAxesFollowDensityAndDirection() {
        val scenario = launch("layout-contract")
        try {
            scenario.onActivity { activity ->
                activity.findViewById<ViewGroup>(R.id.rendererMount).removeAllViews()
                for (dpi in listOf(160, 240, 320)) for (rtl in listOf(false, true))
                    for (widthDp in listOf(400f, 800f)) for (night in listOf(Configuration.UI_MODE_NIGHT_NO, Configuration.UI_MODE_NIGHT_YES)) {
                    val configuration = Configuration(activity.resources.configuration).apply {
                        densityDpi = dpi
                        uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or night
                    }
                    val themed = ContextThemeWrapper(activity.createConfigurationContext(configuration), R.style.Theme_AssetPipeline_AndroidHost)
                    val root = requireNotNull(CrystalBridge.renderStudy(themed, "layout-contract"))
                    root.layoutDirection = if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
                    fun dp(value: Float) = (value * themed.resources.displayMetrics.density).roundToInt()
                    root.measure(View.MeasureSpec.makeMeasureSpec(dp(widthDp), View.MeasureSpec.AT_MOST),
                        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
                    root.layout(0, 0, root.measuredWidth, root.measuredHeight)
                    fun view(id: String) = find(root, id)
                    val bounded = view("bounds-label")
                    assertEquals(dp(90.5f), bounded.width)
                    assertTrue(bounded.height <= dp(45.5f))
                    assertEquals(0, view("zero-size").width)
                    assertEquals(0, view("zero-size").height)
                    for (name in listOf("leading", "center", "trailing", "fill")) {
                        val child = view("vertical-$name-child")
                        assertEquals(dp(if (name == "fill") 200f else 40f), child.width)
                        assertEquals(dp(20f), child.height)
                        val left = when (name) {
                            "leading" -> if (rtl) dp(160f) else 0
                            "trailing" -> if (rtl) 0 else dp(160f)
                            "center" -> (dp(200f) - child.width) / 2
                            else -> 0
                        }
                        assertEquals("VStack $name RTL=$rtl", left, child.left)
                    }
                    for (name in listOf("top", "center", "bottom", "fill")) {
                        val child = view("horizontal-$name-child")
                        assertEquals(dp(40f), child.width)
                        assertEquals(dp(if (name == "fill") 80f else 20f), child.height)
                        assertEquals(when (name) { "top", "fill" -> 0; "bottom" -> dp(60f); else -> dp(30f) }, child.top)
                    }
                    for (name in listOf("leading", "center", "trailing", "top", "bottom", "fill")) {
                        val parent = view("overlay-$name") as ViewGroup
                        val first = view("overlay-$name-first")
                        val last = view("overlay-$name-last")
                        assertSame(first, parent.getChildAt(0)); assertSame(last, parent.getChildAt(1))
                        assertEquals(dp(40f), first.width); assertEquals(dp(20f), first.height)
                        if (name == "fill") { assertEquals(dp(200f), last.width); assertEquals(dp(80f), last.height) }
                        else {
                            assertEquals(dp(20f), last.width); assertEquals(dp(10f), last.height)
                            val x = when (name) { "leading" -> if (rtl) parent.width - last.width else 0; "trailing" -> if (rtl) 0 else parent.width - last.width; else -> (parent.width - last.width) / 2 }
                            val y = when (name) { "top" -> 0; "bottom" -> parent.height - last.height; else -> (parent.height - last.height) / 2 }
                            assertEquals("ZStack $name RTL=$rtl", x, last.left); assertEquals(y, last.top)
                        }
                    }
                    assertEquals(dp(240f) - 2 * dp(40f) - 2 * dp(2.5f), view("horizontal-spacer").width)
                    assertEquals(0, view("horizontal-spacer").height)
                    val spaced = listOf(view("spacer-left"), view("horizontal-spacer"), view("spacer-right"))
                    for ((first, next) in spaced.zipWithNext()) {
                        assertEquals("Default HStack spacing RTL=$rtl", dp(2.5f),
                            if (rtl) first.left - next.right else next.left - first.right)
                    }
                    assertEquals(dp(160f) - 2 * dp(20f) - 2 * dp(3.5f), view("vertical-spacer").height)
                    assertEquals(0, view("vertical-spacer").width)
                    assertEquals(dp(15.5f), view("intrinsic-spacer").width)
                    assertEquals(dp(240f) - dp(40f) - dp(4.5f), view("grow-field").width)
                    assertEquals(dp(80f), view("grow-field").height)
                    for (name in listOf("vertical", "horizontal", "both", "none")) {
                        val scroll = view("scroll-$name")
                        assertEquals(dp(180.5f), scroll.width); assertEquals(dp(100.5f), scroll.height)
                        assertFalse(scroll.isHorizontalScrollBarEnabled); assertFalse(scroll.isVerticalScrollBarEnabled)
                        when (name) {
                            "vertical" -> { assertTrue(scroll is ScrollView); scroll.scrollTo(0, dp(400f)); assertTrue(scroll.scrollY > 0) }
                            "horizontal" -> { assertTrue(scroll is HorizontalScrollView); scroll.scrollTo(dp(600f), 0); assertTrue(scroll.scrollX > 0) }
                            "both" -> {
                                val horizontal = (scroll as ScrollView).getChildAt(0) as HorizontalScrollView
                                assertFalse(horizontal.isHorizontalScrollBarEnabled)
                                horizontal.scrollTo(dp(600f), 0); scroll.scrollTo(0, dp(400f))
                                assertTrue(horizontal.scrollX > 0); assertTrue(scroll.scrollY > 0)
                            }
                            else -> { assertFalse(scroll is ScrollView); assertFalse(scroll is HorizontalScrollView) }
                        }
                    }
                    val slot = view("bounded-fill").parent as View
                    assertEquals(dp(200f), slot.width)
                    assertEquals(dp(90.5f), view("bounded-fill").width)
                    assertEquals((slot.width - view("bounded-fill").width) / 2, view("bounded-fill").left)
                    val flexible = view("flexible-scroll") as ScrollView
                    assertEquals(dp(200f), flexible.height)
                    assertTrue(flexible.isVerticalScrollBarEnabled)
                    flexible.scrollTo(0, dp(400f))
                    assertTrue(flexible.scrollY > 0)
                    Log.i("AssetPipelineLayout", "PASS measured contracts densityDpi=$dpi rtl=$rtl widthDp=$widthDp night=$night bounds=true overlay=true spacers=true axes=true")
                    CrystalBridge.teardown()
                    assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
                }
            }
        } finally { scenario.close() }
    }

    @Test fun equalWidthRowsAllocateTotalSlotsAcrossBoundsDensityAndDirection() {
        val scenario = launch("layout-equal-width")
        try {
            scenario.onActivity { activity ->
                activity.findViewById<ViewGroup>(R.id.rendererMount).removeAllViews()
                for (dpi in listOf(160, 240, 320)) for (rtl in listOf(false, true))
                    for (night in listOf(Configuration.UI_MODE_NIGHT_NO, Configuration.UI_MODE_NIGHT_YES)) {
                    val configuration = Configuration(activity.resources.configuration).apply {
                        densityDpi = dpi
                        uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or night
                    }
                    val themed = ContextThemeWrapper(activity.createConfigurationContext(configuration), R.style.Theme_AssetPipeline_AndroidHost)
                    fun dp(value: Float) = (value * themed.resources.displayMetrics.density).roundToInt()
                    val root = requireNotNull(CrystalBridge.renderStudy(themed, "layout-equal-width"))
                    root.layoutDirection = if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
                    root.measure(View.MeasureSpec.makeMeasureSpec(dp(400f), View.MeasureSpec.AT_MOST),
                        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
                    root.layout(0, 0, root.measuredWidth, root.measuredHeight)
                    fun row(id: String) = find(root, id) as CrystalLinearLayout
                    fun slots(parent: ViewGroup) = (0 until parent.childCount).map { parent.getChildAt(it) }.filter { it.visibility != View.GONE }
                    fun checkSlots(parent: CrystalLinearLayout, gap: Int) {
                        val cells = slots(parent)
                        assertTrue(cells.isNotEmpty())
                        assertTrue("Equal total widths, not equal added slack", cells.maxOf { it.width } - cells.minOf { it.width } <= 1)
                        assertEquals(parent.width - parent.paddingLeft - parent.paddingRight,
                            cells.sumOf { it.width } + (cells.size - 1) * gap)
                        assertEquals(parent.paddingLeft, cells.minOf { it.left })
                        assertEquals(parent.width - parent.paddingRight, cells.maxOf { it.right })
                        for ((first, next) in cells.zipWithNext()) {
                            assertEquals("row=${NativeSemantics.testId(parent)} dpi=$dpi rtl=$rtl night=$night cells=${cells.map { "${it.left}:${it.right}" }}", gap,
                                if (rtl) first.left - next.right else next.left - first.right)
                        }
                        assertTrue(cells.all { NativeSemantics.testId(it) == null })
                    }
                    val pinned = row("equal-pinned")
                    assertTrue("The Crystal HStack property must reach the native host", pinned.crystalFillEqually)
                    assertEquals(dp(241.5f), pinned.width)
                    assertEquals(4, slots(pinned).size)
                    assertEquals(View.GONE, (find(root, "equal-hidden").parent as View).visibility)
                    checkSlots(pinned, dp(2.5f))
                    for ((id, width) in listOf("equal-first" to 20.5f, "equal-second" to 30.5f, "equal-third" to 40.5f)) {
                        val content = find(root, id)
                        val cell = content.parent as ViewGroup
                        assertSame(pinned, cell.parent)
                        assertEquals(dp(width), content.width)
                        assertEquals((cell.width - content.width) / 2, content.left)
                        assertEquals(dp(20.5f), content.height)
                    }
                    val spacer = find(root, "equal-spacer")
                    assertEquals(dp(15.5f), spacer.minimumWidth)
                    assertEquals((spacer.parent as View).width, spacer.width)
                    val ordinary = row("unequal-natural")
                    assertFalse(ordinary.crystalFillEqually)
                    assertNotEquals(find(root, "unequal-natural-short").width, find(root, "unequal-natural-long").width)

                    val natural = row("equal-natural")
                    assertEquals("Native cells must not change shared metadata paths",
                        NativeViewState.nodes(ordinary).map { it.identity }, NativeViewState.nodes(natural).map { it.identity })
                    for ((mode, width) in listOf(View.MeasureSpec.UNSPECIFIED to 0,
                        View.MeasureSpec.AT_MOST to dp(150f), View.MeasureSpec.EXACTLY to dp(301f))) {
                        natural.measure(View.MeasureSpec.makeMeasureSpec(width, mode),
                            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
                        natural.layout(0, 0, natural.measuredWidth, natural.measuredHeight)
                        checkSlots(natural, dp(3.5f))
                        if (mode == View.MeasureSpec.UNSPECIFIED) assertTrue(natural.width > dp(150f))
                        else assertEquals(width, natural.width)
                        assertEquals(slots(natural).first().width, find(root, "equal-natural-short").width)
                        assertTrue(find(root, "equal-natural-bounded").width <= dp(90.5f))
                    }
                    val actions = row("equal-actions")
                    checkSlots(actions, dp(4.5f))
                    assertEquals(dp(70.5f), find(root, "equal-action-a").height)
                    assertEquals(dp(70.5f), find(root, "equal-action-b").height)
                    // The extra native cells must not acquire shared identities.
                    assertEquals(1, NativeViewState.nodes(root).count { NativeSemantics.testId(it.view) == "equal-first" })

                    val empty = CrystalLinearLayout(themed)
                    NativeLayout.configureEqualWidth(empty, true)
                    fun measureEmpty() {
                        empty.measure(View.MeasureSpec.makeMeasureSpec(dp(151.5f), View.MeasureSpec.EXACTLY),
                            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
                        empty.layout(0, 0, empty.measuredWidth, empty.measuredHeight)
                        assertEquals(dp(151.5f), empty.width)
                    }
                    measureEmpty()
                    val only = TextView(themed).apply { text = "Only cell" }
                    NativeLayout.addChild(empty, only)
                    measureEmpty()
                    assertEquals(empty.width, only.width)
                    (only.parent as View).visibility = View.GONE
                    measureEmpty()
                    assertEquals(0, empty.height)
                }
            }
        } finally { scenario.close() }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
        }
    }

    @Test fun equalWidthButtonsKeepCrystalCallbacksAndRecreation() {
        val scenario = launch("layout-equal-width")
        try {
            var expected = 0
            var retired: View? = null
            scenario.onActivity { activity ->
                val root = activity.findViewById<View>(R.id.rendererMount)
                expected = (find(root, "equal-result") as TextView).text.toString().substringAfterLast(' ').toInt()
                retired = find(root, "equal-action-a")
            }
            fun awaitResult() {
                val wanted = "Equal callbacks: $expected"
                val deadline = SystemClock.uptimeMillis() + 5000L
                var actual = ""
                do {
                    scenario.onActivity { activity ->
                        actual = (find(activity.findViewById(R.id.rendererMount), "equal-result") as TextView).text.toString()
                    }
                    if (actual == wanted) break
                    SystemClock.sleep(20L)
                } while (SystemClock.uptimeMillis() < deadline)
                assertEquals(wanted, actual)
                onView(NativeTestIds.withTestId("equal-result")).perform(scrollTo()).check(matches(isDisplayed()))
            }
            for (id in listOf("equal-action-a", "equal-action-b")) {
                onView(NativeTestIds.withTestId(id)).perform(scrollTo(), click())
                expected++
                awaitResult()
            }
            scenario.onActivity {
                assertFalse(requireNotNull(retired).isAttachedToWindow)
                requireNotNull(retired).performClick()
            }
            awaitResult()
            scenario.recreate()
            awaitResult()
        } finally { scenario.close() }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
        }
    }

    @Test fun huggingStacksKeepFillChildrenAtNaturalWidthAndRootFillFillsTheParent() {
        val scenario = launch("layout-hugging")
        try {
            onView(NativeTestIds.withTestId("hug-heading")).perform(scrollTo())
            scenario.onActivity { activity ->
                val mount = activity.findViewById<View>(R.id.rendererMount)
                val bar = find(mount, "hug-bar")
                val heading = find(mount, "hug-heading") as TextView
                val section = find(mount, "hug-section")
                val page = find(mount, "hug-page")
                // A phone measured this section to its 38 dp accent bar and wrapped
                // the heading into that column (QuiltPerfect first contact).
                // The heading is short enough for one line in the host's 287 dp
                // mount; the collapsed layout wrapped it into the bar's column.
                assertEquals("Fill heading keeps one natural line", 1, heading.lineCount)
                assertTrue("Section is far wider than its accent bar", section.width > bar.width * 3)
                assertEquals("Fill heading spans the section", section.width - section.paddingLeft - section.paddingRight, heading.width)
                assertEquals("Page hugs the section", section.width + page.paddingLeft + page.paddingRight, page.width)
                val root = find(mount, "hug-root")
                val content = find(mount, "hug-content")
                assertEquals("root_fill fills the parent's width", content.width - content.paddingLeft - content.paddingRight, root.width)
            }
        } finally { scenario.close() }
    }
    @Test fun aRootThatFillsTheScreenPinsItsBarUnderAScrollingPage() {
        val scenario = launch("layout-fill-screen")
        try {
            onView(NativeTestIds.withTestId("fill-header")).perform(scrollTo())
            scenario.onActivity { activity ->
                val mount = activity.findViewById<View>(R.id.rendererMount)
                val reported = requireNotNull(activity.debugViewport()) { "the host reported no viewport" }
                val expected = (reported.heightDp * activity.resources.displayMetrics.density).roundToInt()
                val root = find(mount, "fill-root")
                val page = find(mount, "fill-page")
                val bar = find(mount, "fill-bar")
                val header = find(mount, "fill-header")
                assertTrue("The host reported a height", expected > 0)
                // The sample host keeps other rows above the mount inside its scrolling column, so
                // the mount is the reported viewport (the container's bar-free height), not its parent.
                assertTrue("The mount takes the reported viewport height: ${mount.height} vs $expected", kotlin.math.abs(mount.height - expected) <= 1)
                assertEquals("The root fills the mount", mount.height, root.height)
                assertEquals("The bar sits at the bottom of the root", root.height, bar.bottom)
                assertTrue("The bar is on screen", bar.isShown && bar.height >= (56 * activity.resources.displayMetrics.density).toInt() - 1)
                assertTrue("The page is the flexible middle: ${page.height} of ${root.height}", page.height > 0 && page.height == root.height - header.height - bar.height)
                val content = (page as ViewGroup).getChildAt(0)
                assertTrue("The page scrolls its taller content: ${content.height} in ${page.height}", content.height > page.height)
            }
        } finally { scenario.close() }
    }
    /** Waits until the two-axis viewport reports the same scroll offsets for 150 ms (no fling in flight). */
    private fun awaitStill(scenario: ActivityScenario<MainActivity>) {
        val deadline = android.os.SystemClock.uptimeMillis() + 5000L
        var last: Pair<Int, Int>? = null
        var stableSince = 0L
        while (android.os.SystemClock.uptimeMillis() < deadline) {
            var now: Pair<Int, Int>? = null
            scenario.onActivity { activity ->
                val scroll = find(activity.findViewById(R.id.rendererMount), "layout-both-scroll") as ScrollView
                now = scroll.scrollY to scroll.getChildAt(0).scrollX
            }
            if (now != null && now == last) {
                if (stableSince == 0L) stableSince = android.os.SystemClock.uptimeMillis()
                if (android.os.SystemClock.uptimeMillis() - stableSince >= 150L) return
            } else stableSince = 0L
            last = now
            android.os.SystemClock.sleep(25L)
        }
        throw AssertionError("Two-axis viewport did not come to rest")
    }
    @Test fun twoAxisViewportReceivesRealGesturesAndReachesCrystalAction() {
        val scenario = launch("layout-interaction")
        try {
            // A software-rendered emulator can drop an injected fling; repeat the
            // real gesture a bounded number of times before judging it.
            var movedX = false
            for (attempt in 1..3) {
                onView(NativeTestIds.withTestId("layout-both-scroll")).perform(scrollTo(), swipeLeft())
                scenario.onActivity { activity ->
                    val scroll = find(activity.findViewById(R.id.rendererMount), "layout-both-scroll") as ScrollView
                    movedX = scroll.getChildAt(0).scrollX > 0
                }
                if (movedX) break
            }
            assertTrue("Horizontal gesture must move the native horizontal viewport", movedX)
            // The same bounded repeat for the vertical fling. Start it from the
            // viewport's center, not its bottom edge: after a 90% scroll-to on a
            // phone's shorter screen that edge sat under the navigation bar, so
            // Espresso's swipeUp() began outside the window and never scrolled.
            var movedY = false
            for (attempt in 1..3) {
                onView(NativeTestIds.withTestId("layout-both-scroll")).perform(
                    GeneralSwipeAction(Swipe.FAST, GeneralLocation.CENTER, GeneralLocation.TOP_CENTER, Press.FINGER))
                scenario.onActivity { activity ->
                    val scroll = find(activity.findViewById(R.id.rendererMount), "layout-both-scroll") as ScrollView
                    movedY = scroll.scrollY > 0
                }
                if (movedY) break
            }
            assertTrue("Vertical gesture must move the native vertical viewport", movedY)
            // A fling is still animating after a fast swipe on a phone, and a
            // ScrollView intercepts the next touch-down to stop it, which would
            // swallow the tap below. Let both viewports come to rest first,
            // then position them and let them rest again.
            awaitStill(scenario)
            scenario.onActivity { activity ->
                val scroll = find(activity.findViewById(R.id.rendererMount), "layout-both-scroll") as ScrollView
                val horizontal = scroll.getChildAt(0) as HorizontalScrollView
                // Deterministic final position after proving both real gestures.
                horizontal.scrollTo(horizontal.getChildAt(0).width, 0)
                scroll.scrollTo(0, horizontal.height)
            }
            awaitStill(scenario)
            onView(withText("Far corner action")).perform(click())
            onView(withText("Scroll callbacks: 1")).check(matches(isDisplayed()))
            scenario.recreate()
            onView(withText("Scroll callbacks: 1")).check(matches(isDisplayed()))
        } finally { scenario.close() }
    }
}
