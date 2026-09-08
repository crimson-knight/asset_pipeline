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
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Private directories contract: Crystal is handed the host's canonical files
 * and cache directories and can write under both. */
@RunWith(AndroidJUnit4::class)
class AndroidDirectoriesContractTest {
    @Test fun crystalIsHandedTheFilesAndCacheDirectoriesAndCanWriteUnderBoth() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val scenario = ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "directories-contract"))
        try {
            assertTrue("Native text did not appear", UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text("Native directories")), 10000L))
            scenario.onActivity { activity ->
                fun text(id: String) = (requireNotNull(NativeTestIds.find(activity.window.decorView, id)) { "missing $id" } as TextView).text.toString()
                val files = activity.filesDir.canonicalPath
                val cache = activity.cacheDir.canonicalPath
                assertEquals("Files $files", text("directories-files"))
                assertEquals("Cache $cache", text("directories-cache"))
                assertEquals("Files write ok", text("directories-files-write"))
                assertEquals("Cache write ok", text("directories-cache-write"))
                assertTrue(File(files, "asset_pipeline_directories_fixture.txt").isFile)
                assertTrue(File(cache, "asset_pipeline_directories_fixture.txt").isFile)
            }
        } finally { scenario.close() }
    }
}
