package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Run each argument in a separate instrumentation process: FAILED is terminal.
 * Never reset a failed production session just to make a test pass.
 */
@RunWith(AndroidJUnit4::class)
class AndroidFailureBoundaryTest {
    private external fun registerFailureNative(kind: Int): Long
    private external fun unregisterFailureNative(id: Long)
    private external fun renderProbeNative(context: Context): Int

    @Test fun containedFailureRejectsReuseAndStillCleansUp() {
        val kind = requireNotNull(InstrumentationRegistry.getArguments().getString("failure_kind")).toInt()
        require(kind in 1..6)
        val context = ApplicationProvider.getApplicationContext<Context>()
        val intent = Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_STUDY_SLUG, "interaction-smoke")
        val scenario = ActivityScenario.launch<MainActivity>(intent)
        var callbackId = 0L
        try {
            scenario.onActivity { activity ->
                val baseline = CrystalBridge.debugCounts()
                // Force failures after real parent/child Views, toolbar and
                // callbacks exist. Check immediate cleanup without invoking GC.
                repeat(100) {
                    assertEquals(1, renderProbeNative(activity))
                    assertEquals(baseline, CrystalBridge.debugCounts())
                }
                var observedRefreshes = 0
                CrystalBridge.callbackObserver = { observedRefreshes++ }
                if (kind <= 5) {
                    callbackId = registerFailureNative(kind)
                    assertTrue(callbackId != 0L)
                }
                assertThrows(IllegalStateException::class.java) {
                    when (kind) {
                        1 -> CrystalBridge.dispatchVoidCallback(callbackId)
                        2 -> CrystalBridge.dispatchStringCallback(callbackId, "private-android-callback-雪\u0000😀")
                        3 -> CrystalBridge.dispatchBoolCallback(callbackId, true)
                        4 -> CrystalBridge.dispatchFloatCallback(callbackId, 2.5)
                        5 -> CrystalBridge.dispatchIntCallback(callbackId, 7)
                        6 -> CrystalBridge.renderStudy(activity, "failure-render")
                    }
                }
                assertEquals(HostSession.State.FAILED, CrystalBridge.debugSessionState())
                assertEquals(0, observedRefreshes)
                assertThrows(IllegalStateException::class.java) { CrystalBridge.dispatchVoidCallback(0) }
                assertThrows(IllegalStateException::class.java) { CrystalBridge.renderStudy(activity, "interaction-smoke") }
                assertThrows(IllegalStateException::class.java) { CrystalBridge.foregroundHost(activity) }
                assertFalse(CrystalBridge.canNavigateBack())
                assertFalse(CrystalBridge.navigateBack())
                if (callbackId != 0L) { unregisterFailureNative(callbackId); callbackId = 0L }
            }
        } finally {
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                if (callbackId != 0L) unregisterFailureNative(callbackId)
            }
            scenario.close()
        }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
            assertEquals(Pair(0, 0), CrystalBridge.debugPendingServices())
            CrystalBridge.closeSession()
            assertEquals(HostSession.State.FAILED, CrystalBridge.debugSessionState())
            assertThrows(IllegalStateException::class.java) { CrystalBridge.attachHost(Any()) }
        }
        InstrumentationRegistry.getInstrumentation().sendStatus(0, Bundle().apply {
            putString("failure_kind", kind.toString())
            putString("failure_process", android.os.Process.myPid().toString())
        })
    }
}
