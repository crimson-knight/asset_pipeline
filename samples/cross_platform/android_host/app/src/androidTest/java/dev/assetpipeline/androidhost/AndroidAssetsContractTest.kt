package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.widget.ImageView
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import java.io.File
import kotlin.math.abs
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Bundled assets contract: the APK's bundle is extracted once per install
 * into private storage, Crystal learns the path, art loads by file path at
 * the density its name declares, a bundled TTF registers under a family name
 * and applies to a label, generic Android families and the system face still
 * resolve, and an unknown name gets what Android gives it. */
@RunWith(AndroidJUnit4::class)
class AndroidAssetsContractTest {
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "assets-contract"))
    }
    private fun awaitText(text: String) = assertTrue("Native text did not appear: $text",
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text(text)), 10000L))
    private fun text(activity: MainActivity, id: String): String =
        (requireNotNull(NativeTestIds.find(activity.window.decorView, id)) { "missing $id" } as TextView).text.toString()

    @Test fun theBundleIsExtractedOncePerInstallAndArtAndFacesResolveFromIt() {
        val scenario = launch()
        try {
            awaitText("Native assets")
            var extractions = -1
            scenario.onActivity { activity ->
                val bundle = requireNotNull(BundledAssets.debugDirectory()) { "the host extracted no bundle" }
                assertTrue("The bundle lives in private storage: $bundle", bundle.canonicalPath.startsWith(activity.filesDir.canonicalPath + "/"))
                assertEquals("Bundle " + bundle.absolutePath, text(activity, "assets-bundle"))
                assertTrue(File(bundle, "fonts/Inter_semibold.ttf").isFile)
                assertEquals("Fonts 1", text(activity, "assets-fonts"))
                assertEquals("Note The bundle is real files: this note is read back by the assets fixture.", text(activity, "assets-note"))
                val density = activity.resources.displayMetrics.density
                val mark = requireNotNull(NativeTestIds.find(activity.window.decorView, "assets-mark")) { "missing mark" } as ImageView
                val drawable = requireNotNull(mark.drawable) { "the mark did not load" }
                val expected = (32f * density).roundToInt()
                assertTrue("A 64 px mark named @2x is 32 dp: ${drawable.intrinsicWidth} of $expected px", abs(drawable.intrinsicWidth - expected) <= 1)
                assertTrue("The view wraps the mark: ${mark.width} of $expected px", abs(mark.width - expected) <= 1)
                val inter = requireNotNull(NativeTestIds.find(activity.window.decorView, "assets-inter")) as TextView
                val registered = requireNotNull(FontAssets.debugTypeface("Inter-SemiBold")) { "the face was not registered" }
                assertEquals("The label wears the registered face", Typeface.create(registered, Typeface.NORMAL), inter.typeface)
                assertNotEquals("The registered face is not the default", Typeface.DEFAULT, inter.typeface)
                val serif = requireNotNull(NativeTestIds.find(activity.window.decorView, "assets-serif")) as TextView
                assertEquals(Typeface.create("serif", Typeface.NORMAL), serif.typeface)
                assertNotEquals(Typeface.DEFAULT, serif.typeface)
                val system = requireNotNull(NativeTestIds.find(activity.window.decorView, "assets-system")) as TextView
                assertEquals(Typeface.defaultFromStyle(Typeface.NORMAL), system.typeface)
                val unknown = requireNotNull(NativeTestIds.find(activity.window.decorView, "assets-unknown")) as TextView
                assertEquals("An unknown name gets what Android gives it", Typeface.create("NoSuchFace-Bold", Typeface.NORMAL), unknown.typeface)
                extractions = BundledAssets.debugExtractions()
            }
            assertTrue("The first launch of an install extracts at most once: $extractions", extractions in 0..1)
            scenario.recreate()
            awaitText("Native assets")
            scenario.onActivity { activity ->
                assertEquals("A recreated host does not extract again", extractions, BundledAssets.debugExtractions())
                assertEquals("Fonts 1", text(activity, "assets-fonts"))
            }
        } finally { scenario.close() }
    }
}
