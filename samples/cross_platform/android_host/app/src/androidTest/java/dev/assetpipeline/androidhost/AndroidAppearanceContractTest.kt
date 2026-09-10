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

/** Appearance contract: the host's night mode reaches Crystal before the render, in both directions. */
@RunWith(AndroidJUnit4::class)
class AndroidAppearanceContractTest {
    private fun answerFor(appearance: String): String {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_APP_SLUG, "appearance-contract")
            .putExtra(MainActivity.EXTRA_STUDY_APPEARANCE, appearance)
        val scenario = ActivityScenario.launch<MainActivity>(intent)
        try {
            assertTrue("Native text did not appear", UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text("Native appearance")), 10000L))
            var answer = ""
            scenario.onActivity { activity ->
                answer = (requireNotNull(NativeTestIds.find(activity.window.decorView, "appearance-answer")) as TextView).text.toString()
            }
            return answer
        } finally { scenario.close() }
    }

    @Test fun theHostsNightModeReachesCrystal() {
        assertEquals("Appearance dark", answerFor("dark"))
        assertEquals("Appearance light", answerFor("light"))
    }
}
