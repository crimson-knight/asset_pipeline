package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Host settings contract: the values the sample host registers before
 * Crystal starts reach the tree by key, and a key the build does not carry
 * reads as absent. */
@RunWith(AndroidJUnit4::class)
class AndroidSettingsContractTest {
    @Test fun registeredSettingsReachCrystalAndAMissingKeyReadsAbsent() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val scenario = ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "settings-contract"))
        try {
            assertTrue("Native text did not appear", UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text("Native host settings")), 10000L))
            scenario.onActivity { activity ->
                val decor = activity.window.decorView
                fun text(id: String): String = (requireNotNull(NativeTestIds.find(decor, id)) { "missing $id" } as TextView).text.toString()
                assertEquals("Name Native Host", text("settings-name"))
                assertEquals("Id SAMPLE01", text("settings-id"))
                assertEquals("Missing absent", text("settings-missing"))
                assertEquals(listOf("SAMPLE_DEMO_ID", "SAMPLE_DISPLAY_NAME"), HostSettings.keys())
            }
        } finally { scenario.close() }
    }
}
