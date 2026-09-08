package dev.assetpipeline.androidhost

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.os.SystemClock
import android.provider.MediaStore
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
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/** Photo picker contract: a delivered photo is decoded off the main looper,
 * fitted to the requested dimension, encoded JPEG and handed to Crystal
 * through the polled state; the real library picker launches and a Back
 * press cancels it. */
@RunWith(AndroidJUnit4::class)
class AndroidPhotoContractTest {
    private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "photo-contract"))
    }
    private fun awaitText(text: String, timeoutMs: Long = 15000L) = assertTrue("Native text did not appear: $text",
        device.wait(Until.hasObject(By.text(text)), timeoutMs))
    private fun text(scenario: ActivityScenario<MainActivity>, id: String): String {
        var value = ""
        scenario.onActivity { activity ->
            value = (requireNotNull(NativeTestIds.find(activity.window.decorView, id)) { "missing $id" } as TextView).text.toString()
        }
        return value
    }
    private fun tap(scenario: ActivityScenario<MainActivity>, id: String) {
        scenario.onActivity { activity -> requireNotNull(NativeTestIds.find(activity.window.decorView, id)) { "missing $id" }.performClick() }
    }
    /** A 3000 by 2000 JPEG in the shared media store, the way a library photo arrives. */
    private fun insertPhoto(context: Context): Uri {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "ap_photo_fixture_${System.currentTimeMillis()}.jpg")
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/AssetPipeline")
        }
        val uri = requireNotNull(resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)) { "media store refused the photo" }
        val bitmap = Bitmap.createBitmap(3000, 2000, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.rgb(102, 80, 227)) }
        requireNotNull(resolver.openOutputStream(uri)).use { assertTrue(bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it)) }
        bitmap.recycle()
        return uri
    }

    @Test fun aDeliveredPhotoIsFittedEncodedAndHandedToCrystal() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val uri = insertPhoto(context)
        val scenario = launch()
        try {
            awaitText("Native photos")
            assertEquals("State Idle", text(scenario, "photo-state"))
            scenario.onActivity { PhotoPicker.debugDeliver(uri) }
            awaitText("State Ready")
            assertEquals("The longest edge fits 2000 and the aspect holds", "Size 2000x1333", text(scenario, "photo-size"))
            val bytes = text(scenario, "photo-bytes").substringAfterLast(' ').toInt()
            assertTrue("A fitted JPEG has a plausible size: $bytes", bytes in 10_000..PhotoPicker.MAX_BYTES)
            assertEquals("Error none", text(scenario, "photo-error"))
            tap(scenario, "photo-reset")
            awaitText("State Idle")
            assertEquals("Bytes 0", text(scenario, "photo-bytes"))
        } finally {
            scenario.close()
            context.contentResolver.delete(uri, null, null)
        }
    }

    @Test fun theLibraryPickerLaunchesAndABackPressCancelsIt() {
        val scenario = launch()
        try {
            awaitText("Native photos")
            assertTrue("The library is available once the host is attached", text(scenario, "photo-available").startsWith("Library true"))
            var before = 0
            scenario.onActivity { before = PhotoPicker.debugLaunches() }
            tap(scenario, "photo-library")
            val deadline = SystemClock.uptimeMillis() + 5000L
            while (true) {
                var launched = 0
                scenario.onActivity { launched = PhotoPicker.debugLaunches() }
                if (launched == before + 1) break
                if (SystemClock.uptimeMillis() >= deadline) fail("The picker was not launched")
                SystemClock.sleep(100L)
            }
            // Give the system picker its window, then leave it the way a person would.
            SystemClock.sleep(2500L)
            device.pressBack()
            awaitText("State Cancelled", 20000L)
        } finally { scenario.close() }
    }
}
