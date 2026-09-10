package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.TextView
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/** Host tick contract: ticks advance without a touch, each tick's invalidate
 * lands one render, and a backgrounded surface receives none. */
@RunWith(AndroidJUnit4::class)
class AndroidTickContractTest {
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "tick-contract"))
    }
    private fun awaitText(text: String) = assertTrue("Native text did not appear: $text",
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text(text)), 10000L))
    /** The trailing integer of a counter label, read on the main thread. */
    private fun count(scenario: ActivityScenario<MainActivity>, id: String): Int {
        var value = -1
        scenario.onActivity { activity ->
            val label = requireNotNull(NativeTestIds.find(activity.window.decorView, id)) { "missing $id" } as TextView
            value = label.text.toString().substringAfterLast(' ').toInt()
        }
        return value
    }
    private fun awaitCount(scenario: ActivityScenario<MainActivity>, id: String, timeoutMs: Long, message: String, accept: (Int) -> Boolean): Int {
        val deadline = SystemClock.uptimeMillis() + timeoutMs
        while (true) {
            val value = count(scenario, id)
            if (accept(value)) return value
            if (SystemClock.uptimeMillis() >= deadline) fail("$message (last $id $value)")
            SystemClock.sleep(100L)
        }
    }
    private fun dispatched(scenario: ActivityScenario<MainActivity>): Long {
        var value = -1L
        scenario.onActivity { value = CrystalBridge.debugTickCount() }
        return value
    }

    @Test fun ticksAdvanceWithoutATouchAndEachTickLandsOneRender() {
        val scenario = launch()
        try {
            awaitText("Native tick")
            val firstTicks = awaitCount(scenario, "tick-count", 3000L, "The first tick did not land") { it >= 1 }
            val firstRenders = count(scenario, "tick-renders")
            val laterTicks = awaitCount(scenario, "tick-count", 4000L, "Ticks stopped advancing") { it >= firstTicks + 2 }
            val laterRenders = count(scenario, "tick-renders")
            val tickDelta = laterTicks - firstTicks
            val renderDelta = laterRenders - firstRenders
            assertTrue("Each tick must land one render: ticks +$tickDelta, renders +$renderDelta",
                renderDelta >= tickDelta - 1 && renderDelta <= tickDelta + 1)
            assertTrue("The host's tick count must cover Crystal's", dispatched(scenario) >= laterTicks)
        } finally { scenario.close() }
    }

    @Test fun aBackgroundedSurfaceReceivesNoTicksAndTheNextOneFollowsResume() {
        val scenario = launch()
        try {
            awaitText("Native tick")
            awaitCount(scenario, "tick-count", 3000L, "The first tick did not land") { it >= 1 }
            scenario.moveToState(Lifecycle.State.CREATED)
            val paused = dispatched(scenario)
            scenario.onActivity { assertEquals(HostSession.State.BACKGROUND, CrystalBridge.debugSessionState()) }
            SystemClock.sleep(2500L)
            assertEquals("A backgrounded surface must receive no ticks", paused, dispatched(scenario))
            val shown = count(scenario, "tick-count")
            scenario.moveToState(Lifecycle.State.RESUMED)
            val resumed = awaitCount(scenario, "tick-count", 3000L, "The tick did not resume") { it > shown }
            assertTrue("Resume must not replay the ticks missed in the background: $shown then $resumed", resumed <= shown + 2)
        } finally { scenario.close() }
    }
}
