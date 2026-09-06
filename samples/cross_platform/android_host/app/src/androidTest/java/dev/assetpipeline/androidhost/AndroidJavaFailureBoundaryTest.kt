package dev.assetpipeline.androidhost

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.res.Resources
import android.os.Bundle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Terminal error at the end: run separately from the positive test process. */
@RunWith(AndroidJUnit4::class)
class AndroidJavaFailureBoundaryTest {
    private external fun renderProbeNative(context: Context, kind: Int): Int

    @Test fun javaErrorsUnwindCrystalOwnershipAndPreserveOriginalThrowable() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val scenario = ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_APP_SLUG, "dialogs-contract"))
        try {
            onView(NativeTestIds.withTestId("dialog-open-alert")).perform(scrollTo(), click())
            val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
            assertTrue(device.wait(Until.hasObject(By.text("Native alert 雪 😀")), 10_000L))
            scenario.onActivity { activity ->
                assertEquals(1, CrystalBridge.debugDialogCount())
                val baseline = CrystalBridge.debugCounts()
                val types = listOf(ClassNotFoundException::class.java, NoSuchMethodError::class.java,
                    JavaFixtureFailure::class.java, JavaFixtureFailure::class.java,
                    ClassNotFoundException::class.java, IndexOutOfBoundsException::class.java,
                    IllegalArgumentException::class.java, ClassNotFoundException::class.java)
                for ((index, type) in types.withIndex()) repeat(50) {
                    assertThrows("Java failure kind ${index + 1}", type) { renderProbeNative(activity, index + 1) }
                    assertEquals("Immediate native cleanup for Java failure kind ${index + 1}", baseline, CrystalBridge.debugCounts())
                    assertEquals(HostSession.State.FOREGROUND, CrystalBridge.debugSessionState())
                    assertEquals(1, CrystalBridge.debugDialogCount())
                }
                // The public host must preserve the actual Throwable identity,
                // become terminal, and still allow normal ownership cleanup.
                val original = JavaFixtureFailure("private-java-public-render")
                val throwingContext = object : ContextWrapper(activity) {
                    override fun getResources(): Resources = throw original
                    override fun getTheme(): Resources.Theme = throw original
                }
                assertSame(original, assertThrows(JavaFixtureFailure::class.java) {
                    CrystalBridge.renderStudy(throwingContext, "interaction-smoke")
                })
                assertEquals(HostSession.State.FAILED, CrystalBridge.debugSessionState())
                assertEquals(0, CrystalBridge.debugDialogCount())
                assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
                assertThrows(IllegalStateException::class.java) { CrystalBridge.renderStudy(activity, "interaction-smoke") }
                assertThrows(IllegalStateException::class.java) { CrystalBridge.dispatchVoidCallback(0) }
            }
            assertTrue(device.wait(Until.gone(By.text("Native alert 雪 😀")), 5000L))
        } finally { scenario.close() }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            CrystalBridge.closeSession()
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
            assertEquals(Pair(0, 0), CrystalBridge.debugPendingServices())
            assertEquals(HostSession.State.FAILED, CrystalBridge.debugSessionState())
        }
        InstrumentationRegistry.getInstrumentation().sendStatus(0, Bundle().apply {
            putString("java_failure_process", android.os.Process.myPid().toString())
            putString("java_failure_probes", "400")
        })
    }
}
