package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.espresso.matcher.RootMatchers.isPlatformPopup
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.google.android.material.tabs.TabLayout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Tabs and menus Tier A: a Material tab bar switches Crystal-owned content, and menu buttons open platform popup menus whose picks reach Crystal. */
@RunWith(AndroidJUnit4::class)
class AndroidTabsContractTest {
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "tabs-contract"))
    }
    private fun awaitText(text: String) = assertTrue("Native text did not update: $text",
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text(text)), 10000L))
    private fun awaitEcho(id: String, text: String) { onView(NativeTestIds.withTestId(id)).perform(scrollTo()); awaitText(text) }
    private fun view(activity: MainActivity, id: String): View = requireNotNull(NativeTestIds.find(activity.window.decorView, id)) { "missing $id" }
    private fun find(activity: MainActivity, id: String): View? = NativeTestIds.find(activity.window.decorView, id)
    private fun descendants(group: ViewGroup): List<View> = (0 until group.childCount).map(group::getChildAt)
        .flatMap { child -> listOf(child) + if (child is ViewGroup) descendants(child) else emptyList() }
    private fun tabLayout(activity: MainActivity): TabLayout =
        requireNotNull(descendants(view(activity, "tabs-view") as ViewGroup).filterIsInstance<TabLayout>().firstOrNull()) { "no TabLayout" }

    @Test fun tabViewRendersMaterialTabsAndCrystalSwitchesTheContentAcrossRecreation() {
        val scenario = launch()
        try {
            awaitEcho("tabs-echo", "Tab: 0; changes: 0")
            scenario.onActivity { activity ->
                val tabs = tabLayout(activity)
                assertEquals(3, tabs.tabCount)
                assertEquals(listOf("Home", "Search", "Profile"), (0 until tabs.tabCount).map { tabs.getTabAt(it)!!.text.toString() })
                assertEquals(0, tabs.selectedTabPosition)
                assertEquals("bar above the content", 0, (view(activity, "tabs-view") as ViewGroup).indexOfChild(tabs))
                assertNotNull("selected tab content", find(activity, "tabs-home"))
                assertNull("unselected tab content is not rendered", find(activity, "tabs-search"))
            }
            scenario.onActivity { tabLayout(it).getTabAt(1)!!.select() }
            awaitEcho("tabs-echo", "Tab: 1; changes: 1")
            scenario.onActivity { activity ->
                assertEquals(1, tabLayout(activity).selectedTabPosition)
                assertNotNull(find(activity, "tabs-search"))
                assertNull(find(activity, "tabs-home"))
            }
            scenario.recreate()
            awaitEcho("tabs-echo", "Tab: 1; changes: 1")
            scenario.onActivity { activity ->
                assertEquals(1, tabLayout(activity).selectedTabPosition)
                assertNotNull(find(activity, "tabs-search"))
                assertNull(find(activity, "tabs-home"))
            }
        } finally { scenario.close() }
    }

    @Test fun menuButtonsOpenPlatformPopupMenusAndPicksReachCrystalAcrossRecreation() {
        val scenario = launch()
        try {
            awaitEcho("tabs-menu-echo", "Picked: none; picks: 0")
            scenario.onActivity { activity ->
                assertEquals("pull-down face shows its label", "Actions", (view(activity, "tabs-menu") as Button).text.toString())
                assertEquals("pop-up face shows the selection", "Medium", (view(activity, "tabs-choice") as Button).text.toString())
            }
            NativeTaps.tap({ onView(NativeTestIds.withTestId("tabs-menu")) })
            onView(withText("Duplicate")).inRoot(isPlatformPopup()).perform(click())
            awaitEcho("tabs-menu-echo", "Picked: Duplicate; picks: 1")
            NativeTaps.tap({ onView(NativeTestIds.withTestId("tabs-menu")) })
            onView(withText("Delete")).inRoot(isPlatformPopup()).perform(click())
            awaitEcho("tabs-menu-echo", "Picked: Delete; picks: 2")
            NativeTaps.tap({ onView(NativeTestIds.withTestId("tabs-choice")) })
            onView(withText("Large")).inRoot(isPlatformPopup()).perform(click())
            awaitEcho("tabs-choice-echo", "Choice: Large")
            scenario.onActivity { assertEquals("Large", (view(it, "tabs-choice") as Button).text.toString()) }
            scenario.recreate()
            awaitEcho("tabs-menu-echo", "Picked: Delete; picks: 2")
            awaitEcho("tabs-choice-echo", "Choice: Large")
            scenario.onActivity { assertEquals("Large", (view(it, "tabs-choice") as Button).text.toString()) }
        } finally { scenario.close() }
    }
}
