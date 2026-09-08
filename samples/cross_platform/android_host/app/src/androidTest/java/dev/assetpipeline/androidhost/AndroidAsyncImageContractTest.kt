package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import kotlin.math.abs
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** AsyncImage contract: preloaded bytes decode into the view at the declared
 * content mode inside its frame, and an image with no bytes shows its
 * placeholder instead of an empty view. */
@RunWith(AndroidJUnit4::class)
class AndroidAsyncImageContractTest {
    @Test fun preloadedBytesDrawAtEachContentModeAndTheWaitingImageShowsItsPlaceholder() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val scenario = ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "async-image-contract"))
        try {
            assertTrue("Native text did not appear", UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text("Native async images")), 10000L))
            scenario.onActivity { activity ->
                val decor = activity.window.decorView
                val density = activity.resources.displayMetrics.density
                val bytes = (requireNotNull(NativeTestIds.find(decor, "async-bytes")) as TextView).text.toString().substringAfterLast(' ').toInt()
                assertTrue("The bundle's mark was handed over as bytes: $bytes", bytes > 100)
                val expectedScale = mapOf("async-fit" to ImageView.ScaleType.FIT_CENTER, "async-fill" to ImageView.ScaleType.CENTER_CROP, "async-stretch" to ImageView.ScaleType.FIT_XY)
                for ((id, scale) in expectedScale) {
                    val image = requireNotNull(NativeTestIds.find(decor, id)) { "missing $id" } as ImageView
                    val drawable = requireNotNull(image.drawable) { "$id has no drawable" }
                    // Preloaded bytes are photos at their own pixels: one pixel per pixel.
                    assertEquals("$id decoded the 64 px mark", 64, drawable.intrinsicWidth)
                    assertEquals("$id decoded the 64 px mark", 64, drawable.intrinsicHeight)
                    assertEquals("$id scale type", scale, image.scaleType)
                    val frame = (96f * density).roundToInt()
                    assertTrue("$id keeps its frame: ${image.width} of $frame", abs(image.width - frame) <= 1)
                }
                val waiting = requireNotNull(NativeTestIds.find(decor, "async-waiting")) { "missing async-waiting" }
                assertTrue("An image with no bytes is the container of its placeholder, not an empty ImageView", waiting is ViewGroup && waiting !is ImageView)
                val placeholder = requireNotNull(NativeTestIds.find(decor, "async-placeholder")) { "the placeholder was not rendered" } as TextView
                assertEquals("Loading photo", placeholder.text.toString())
                assertTrue("The placeholder is on screen", placeholder.isShown)
            }
        } finally { scenario.close() }
    }
}
