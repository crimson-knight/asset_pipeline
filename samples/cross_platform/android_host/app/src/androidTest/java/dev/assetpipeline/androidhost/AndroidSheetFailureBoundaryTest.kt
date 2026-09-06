package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.EditText
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.espresso.matcher.RootMatchers.isDialog
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** A terminal window-mutation failure requires a separate test process. */
@RunWith(AndroidJUnit4::class)
class AndroidSheetFailureBoundaryTest {
    @Test fun delayedWindowMutationFailureRetiresTheWindowBeforeOldControlsCanDispatch() {
        val scenario = ActivityScenario.launch<MainActivity>(Intent(
            ApplicationProvider.getApplicationContext<Context>(), MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_APP_SLUG, "sheets-contract"))
        try {
            onView(NativeTestIds.withTestId("sheet-open")).perform(scrollTo(), click())
            var editor: EditText? = null
            var button: View? = null
            onView(NativeTestIds.withTestId("sheet-draft")).inRoot(isDialog()).check { view, error ->
                if (error != null) throw error
                editor = NativeSemantics.target(view) as EditText
            }
            onView(NativeTestIds.withTestId("sheet-done")).inRoot(isDialog()).check { view, error ->
                if (error != null) throw error
                button = view
            }
            scenario.onActivity {
                assertEquals(1, CrystalBridge.debugDialogCount())
                val original = IllegalStateException("private-sheet-window-mutation")
                assertSame(original, assertThrows(IllegalStateException::class.java) {
                    CrystalBridge.windowMutation { throw original }
                })
                assertEquals(HostSession.State.FAILED, CrystalBridge.debugSessionState())
                assertEquals(0, CrystalBridge.debugDialogCount())
                assertFalse(NativeWindowScope.allows(editor))
                assertFalse(NativeWindowScope.allows(button))
                val retiredCounts = CrystalBridge.debugCounts()
                editor!!.setText("private-sheet-retired-control")
                button!!.performClick()
                assertEquals(retiredCounts, CrystalBridge.debugCounts())
                assertThrows(IllegalStateException::class.java) { CrystalBridge.completeSheetTransition(true) }
            }
        } finally { scenario.close() }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            CrystalBridge.closeSession()
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
            assertEquals(Pair(0, 0), CrystalBridge.debugPendingServices())
            assertEquals(HostSession.State.FAILED, CrystalBridge.debugSessionState())
        }
        InstrumentationRegistry.getInstrumentation().sendStatus(0, Bundle().apply {
            putString("sheet_failure_process", android.os.Process.myPid().toString())
        })
    }
}
