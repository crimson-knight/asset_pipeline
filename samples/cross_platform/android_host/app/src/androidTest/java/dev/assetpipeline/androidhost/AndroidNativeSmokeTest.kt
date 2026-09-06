package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.SystemClock
import android.widget.EditText
import android.widget.TextView
import android.graphics.drawable.GradientDrawable
import android.graphics.Rect
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PorterDuff
import android.widget.ImageView
import android.util.TypedValue
import android.util.Log
import android.view.ContextThemeWrapper
import android.view.View
import android.view.ViewGroup
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import kotlin.math.roundToInt
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.closeSoftKeyboard
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.espresso.action.ViewActions.typeText
import androidx.test.espresso.action.ViewActions.typeTextIntoFocusedView
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isAssignableFrom
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import androidx.lifecycle.Lifecycle
import androidx.core.graphics.ColorUtils
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.android.material.color.MaterialColors
import org.hamcrest.Matchers.containsString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidNativeSmokeTest {
    @Test
    fun nativeImagesPackageUnicodeNamesScaleTintAndResolveCurrentConfiguration() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_STUDY_SLUG, "image-smoke")
        }
        val scenario = ActivityScenario.launch<MainActivity>(intent)
        try {
            scenario.onActivity { activity ->
                activity.findViewById<ViewGroup>(R.id.rendererMount).removeAllViews()
                for (dpi in listOf(160, 320)) {
                    for (night in listOf(Configuration.UI_MODE_NIGHT_NO, Configuration.UI_MODE_NIGHT_YES)) {
                        val configuration = Configuration(activity.resources.configuration).apply {
                            densityDpi = dpi
                            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or night
                        }
                        val themed = ContextThemeWrapper(activity.createConfigurationContext(configuration), R.style.Theme_AssetPipeline_AndroidHost)
                        val root = requireNotNull(CrystalBridge.renderStudy(themed, "image-smoke"))
                        root.measure(View.MeasureSpec.makeMeasureSpec(400 * dpi / 160, View.MeasureSpec.AT_MOST), View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
                        root.layout(0, 0, root.measuredWidth, root.measuredHeight)
                        fun image(id: String) = describedView(root, id) as ImageView
                        fun pixel(view: ImageView, x: Float, y: Float): Int {
                            assertEquals(80 * dpi / 160, view.width)
                            assertEquals(80 * dpi / 160, view.height)
                            val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
                            return try {
                                view.draw(Canvas(bitmap))
                                bitmap.getPixel((view.width * x).toInt(), (view.height * y).toInt())
                            } finally { bitmap.recycle() }
                        }
                        val fit = image("image-fit")
                        val fill = image("image-fill")
                        val stretch = image("image-stretch")
                        val tint = image("image-tint")
                        val untinted = image("image-untinted")
                        assertEquals(ImageView.ScaleType.FIT_CENTER, fit.scaleType)
                        assertEquals(ImageView.ScaleType.CENTER_CROP, fill.scaleType)
                        assertEquals(ImageView.ScaleType.FIT_XY, stretch.scaleType)
                        assertEquals(Color.TRANSPARENT, pixel(fit, 0.25f, 0.1f))
                        assertEquals(if (night == Configuration.UI_MODE_NIGHT_YES) Color.GREEN else Color.RED, pixel(fit, 0.25f, 0.5f))
                        assertEquals(if (night == Configuration.UI_MODE_NIGHT_YES) Color.YELLOW else Color.BLUE, pixel(fit, 0.75f, 0.5f))
                        assertEquals(Color.RED, pixel(fill, 0.25f, 0.1f))
                        assertEquals(Color.BLUE, pixel(stretch, 0.75f, 0.1f))
                        assertEquals(PorterDuff.Mode.SRC_IN, tint.imageTintMode)
                        assertEquals(Color.GREEN, tint.imageTintList!!.defaultColor)
                        assertEquals(Color.GREEN, pixel(tint, 0.25f, 0.5f))
                        assertEquals(Color.GREEN, pixel(tint, 0.75f, 0.5f))
                        assertEquals(Color.RED, pixel(untinted, 0.25f, 0.5f))
                        assertEquals(Color.BLUE, pixel(untinted, 0.75f, 0.5f))
                        assertEquals(Color.RED, pixel(image("image-raster"), 0.25f, 0.5f))
                        assertEquals(Color.BLUE, pixel(image("image-raster"), 0.75f, 0.5f))
                        // JPEG is lossy: require strong red/blue channels, not
                        // bit-exact PNG colors after platform decoding.
                        val jpegRed = pixel(image("image-jpeg"), 0.25f, 0.5f)
                        val jpegBlue = pixel(image("image-jpeg"), 0.75f, 0.5f)
                        assertTrue(Color.red(jpegRed) > 240 && Color.blue(jpegRed) < 15)
                        assertTrue(Color.blue(jpegBlue) > 240 && Color.red(jpegBlue) < 15)
                        val limited = ImageView(themed)
                        assertEquals(false, ImageAssets.setSource(limited, "too_many_pixels".toByteArray()))
                        assertEquals(false, ImageAssets.setSource(limited, "too_wide".toByteArray()))
                        assertEquals("Density scaling must be bounded before allocation", dpi == 160, ImageAssets.setSource(limited, "density_limit".toByteArray()))
                        val existing = fit.drawable
                        for (bad in listOf(byteArrayOf(0xc3.toByte(), 0x28), "missing-name".toByteArray(), "https://example.com/image.png".toByteArray(), "../contrast".toByteArray(), ByteArray(1025) { 65 })) {
                            assertEquals(false, ImageAssets.setSource(fit, bad))
                            assertSame("Invalid sources must not replace an existing drawable", existing, fit.drawable)
                        }
                        CrystalBridge.teardown()
                        assertEquals(CrystalBridge.NativeDebugCounts(0, 0), nativeCounts())
                        Log.i("AssetPipelineImages", "PASS densityDpi=$dpi night=$night unicode=true fit=true fill=true stretch=true tintIsolation=true png=true jpeg=true decoderBounds=true")
                    }
                }
            }
        } finally { scenario.close() }
        assertEquals(CrystalBridge.NativeDebugCounts(0, 0), nativeCounts())
    }

    private fun nativeCounts(): CrystalBridge.NativeDebugCounts {
        if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) return CrystalBridge.debugCounts()
        var result: CrystalBridge.NativeDebugCounts? = null
        InstrumentationRegistry.getInstrumentation().runOnMainSync { result = CrystalBridge.debugCounts() }
        return requireNotNull(result)
    }

    @Test
    fun nativeLayoutScalesLogicalDimensionsAndPreservesTextScale() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_STUDY_SLUG, "density-smoke")
        }
        val scenario = ActivityScenario.launch<MainActivity>(intent)
        try {
            scenario.onActivity { activity ->
                activity.findViewById<ViewGroup>(R.id.rendererMount).removeAllViews()
                for (dpi in listOf(160, 320)) {
                    for (fontScale in listOf(1.0f, 1.5f)) {
                        val configuration = Configuration(activity.resources.configuration).apply {
                            densityDpi = dpi
                            this.fontScale = fontScale
                        }
                        val themed = ContextThemeWrapper(activity.createConfigurationContext(configuration), R.style.Theme_AssetPipeline_AndroidHost)
                        val metrics = themed.resources.displayMetrics
                        assertEquals(dpi / 160.0f, metrics.density, 0.001f)
                        fun dp(value: Float) = (value * metrics.density).roundToInt()
                        val root = requireNotNull(CrystalBridge.renderStudy(themed, "density-smoke"))
                        root.measure(View.MeasureSpec.makeMeasureSpec(dp(400f), View.MeasureSpec.AT_MOST), View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
                        root.layout(0, 0, root.measuredWidth, root.measuredHeight)

                        assertEquals(dp(10.5f), root.paddingLeft)
                        assertEquals(dp(7.5f), root.paddingTop)
                        assertEquals(dp(11.5f), root.paddingRight)
                        assertEquals(dp(9.5f), root.paddingBottom)
                        val label = describedView(root, "density-label") as TextView
                        assertEquals(dp(128.5f), label.measuredWidth)
                        assertEquals(dp(48.5f), label.measuredHeight)
                        assertEquals(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 18f, metrics), label.textSize, 0.01f)
                        assertEquals(3.5f * metrics.density, label.elevation, 0.01f)
                        assertEquals(8.5f * metrics.density, (label.background as GradientDrawable).cornerRadius, 0.01f)

                        val row = describedView(root, "density-row")
                        assertEquals("Spacing must ignore the hidden sibling", dp(12.5f), row.top - label.bottom)
                        val first = describedView(root, "density-a")
                        val second = describedView(root, "density-b")
                        assertEquals(dp(28.5f), first.measuredWidth)
                        assertEquals(dp(32.5f), second.measuredWidth)
                        assertEquals(dp(7.5f), second.left - first.right)
                        val button = describedView(root, "density-button") as MaterialButton
                        assertEquals(dp(9.5f), button.cornerRadius)
                        assertEquals(dp(1f), button.strokeWidth)
                        assertEquals(dp(24f), button.paddingLeft)
                        assertEquals(dp(14f), button.paddingTop)
                        val card = describedView(root, "density-card") as MaterialCardView
                        assertEquals(6.5f * metrics.density, card.radius, 0.01f)
                        assertEquals(2.5f * metrics.density, card.cardElevation, 0.01f)
                        assertEquals(dp(1f), card.strokeWidth)
                        val cardContent = card.getChildAt(0)
                        assertEquals(dp(5.5f), cardContent.paddingLeft)
                        assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, cardContent.layoutParams.width)
                        assertEquals(ViewGroup.LayoutParams.WRAP_CONTENT, cardContent.layoutParams.height)
                        Log.i("AssetPipelineLayout", "PASS densityDpi=$dpi fontScale=$fontScale size=${root.measuredWidth}x${root.measuredHeight}")
                        CrystalBridge.teardown()
                        assertEquals(CrystalBridge.NativeDebugCounts(0, 0), nativeCounts())
                    }
                }
            }
        } finally {
            scenario.close()
        }
    }

    private fun describedView(root: View, description: String): View {
        fun find(view: View): View? {
            if (NativeSemantics.testId(view) == description) return view
            if (view is ViewGroup) {
                for (index in 0 until view.childCount) find(view.getChildAt(index))?.let { return it }
            }
            return null
        }
        return requireNotNull(find(root)) { "Native view missing: $description" }
    }

    @Test
    fun rendererUsesRequestedThemeAndStaysInsideSystemBars() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        for (appearance in listOf("light", "dark")) {
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra(MainActivity.EXTRA_STUDY_SLUG, "buttons")
                putExtra(MainActivity.EXTRA_STUDY_APPEARANCE, appearance)
            }
            val scenario = ActivityScenario.launch<MainActivity>(intent)
            try {
                onView(withText(containsString("Renderer mount live"))).check(matches(isDisplayed()))
                scenario.onActivity { activity ->
                    val night = activity.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                    assertEquals(if (appearance == "dark") Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO, night)
                    val toolbar = activity.findViewById<android.view.View>(R.id.toolbar)
                    val bars = ViewCompat.getRootWindowInsets(toolbar)!!.getInsets(WindowInsetsCompat.Type.systemBars())
                    val location = IntArray(2)
                    toolbar.getLocationOnScreen(location)
                    assertTrue("Toolbar must stay below the status bar", location[1] >= bars.top)
                    val surface = MaterialColors.getColor(activity, com.google.android.material.R.attr.colorSurface, 0)
                    assertEquals("Surface luminance must match the requested appearance", appearance == "dark", ColorUtils.calculateLuminance(surface) < 0.5)
                }
                onView(withText("Material button defaults")).check { view, error ->
                    if (error != null) throw error
                    val label = view as TextView
                    assertEquals("Crystal labels must resolve the host theme", MaterialColors.getColor(label, com.google.android.material.R.attr.colorOnSurface), label.currentTextColor)
                }
            } finally {
                scenario.close()
            }
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), nativeCounts())
        }
    }

    @Test
    fun crystalRendererHandlesInputCallbackRerenderAndActivityRecreation() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_STUDY_SLUG, "interaction-smoke")
            putExtra(MainActivity.EXTRA_STUDY_APPEARANCE, "light")
            putExtra(MainActivity.EXTRA_STUDY_STORY, "instrumented Android proof")
        }
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

        val scenario = ActivityScenario.launch<MainActivity>(intent)
        try {
            onView(withText(containsString("Renderer mount live")))
                .check(matches(isDisplayed()))
            // The C once gate must survive repeated calls from JVM workers
            // while preserving the runtime that owns this mounted view tree.
            val initializationCounts = java.util.concurrent.CopyOnWriteArrayList<Int>()
            val workers = List(8) {
                Thread { initializationCounts.add(CrystalBridge.debugInitializeAgainNative()) }
            }
            workers.forEach { it.start() }
            workers.forEach { it.join(5_000) }
            assertEquals(List(8) { 1 }, initializationCounts.toList())
            onView(isAssignableFrom(EditText::class.java))
                .perform(scrollTo(), click())
            var originalEditor: EditText? = null
            onView(isAssignableFrom(EditText::class.java)).check { view, error ->
                if (error != null) throw error
                originalEditor = view as EditText
                // Appending is intentional. A click in a compact native field
                // otherwise puts the caret in the middle of the existing text.
                originalEditor!!.setSelection(originalEditor!!.text.length)
            }
            // IME animations do not participate in Espresso's ordinary idle
            // tracking. Require the editor to be fully visible above the real
            // keyboard before sending keys; never paper over hidden input by
            // replacing its text programmatically.
            val keyboardDeadline = SystemClock.uptimeMillis() + UI_TIMEOUT_MS
            var editorReady = false
            var editorBounds = ""
            while (!editorReady && SystemClock.uptimeMillis() < keyboardDeadline) {
                scenario.onActivity { activity ->
                    val editor = requireNotNull(originalEditor)
                    val insets = ViewCompat.getRootWindowInsets(editor)
                    val rect = Rect()
                    val visible = editor.getGlobalVisibleRect(rect)
                    val imeHeight = insets?.getInsets(WindowInsetsCompat.Type.ime())?.bottom ?: 0
                    val keyboardTop = activity.windowManager.currentWindowMetrics.bounds.bottom - imeHeight
                    editorReady = insets?.isVisible(WindowInsetsCompat.Type.ime()) == true &&
                        visible && rect.height() == editor.height && rect.bottom <= keyboardTop && editor.hasFocus()
                    editorBounds = "rect=$rect height=${editor.height} keyboardTop=$keyboardTop imeHeight=$imeHeight"
                }
                if (!editorReady) SystemClock.sleep(50L)
            }
            assertTrue("Focused editor must remain above the software keyboard: $editorBounds", editorReady)

            // Key-by-key input reproduces the focused-editor lifecycle that a
            // direct setText call cannot cover. The bridge must not replace the
            // native EditText while these callbacks are still being delivered.
            "goal".forEachIndexed { index, character ->
                onView(isAssignableFrom(EditText::class.java)).perform(typeTextIntoFocusedView(character.toString()))
                SystemClock.sleep(KEYSTROKE_SETTLE_MS)
                onView(isAssignableFrom(EditText::class.java)).check { view, error ->
                    if (error != null) throw error
                    assertSame(
                        "A string callback must not replace the focused native editor",
                        originalEditor,
                        view
                    )
                    assertTrue("The native editor should retain focus", view.hasFocus())
                    val editor = view as EditText
                    val expected = "Draft note" + "goal".take(index + 1)
                    assertEquals(expected, editor.text.toString())
                    assertEquals(expected.length, editor.selectionStart)
                    assertEquals(expected.length, editor.selectionEnd)
                }
            }
            onView(isAssignableFrom(EditText::class.java)).check { view, error ->
                if (error != null) throw error
                assertEquals("Draft notegoal", (view as EditText).text.toString())
            }
            onView(isAssignableFrom(EditText::class.java)).perform(closeSoftKeyboard())

            onView(withText("Fire callback")).perform(scrollTo(), click())
            assertTrue(
                "The Kotlin listener should invoke Crystal and request a rerender",
                device.wait(Until.hasObject(By.text("Button callback reached.")), UI_TIMEOUT_MS)
            )
            assertTrue(
                "The rerender should expose the complete Crystal-owned text state",
                device.wait(
                    Until.hasObject(By.text("Text value: Draft notegoal")),
                    UI_TIMEOUT_MS
                )
            )

            val mountedCounts = nativeCounts()
            assertTrue("The mounted tree should own JNI global references", mountedCounts.globalReferences > 0)
            assertTrue("The mounted tree should retain Crystal callbacks", mountedCounts.callbacks > 0)
            repeat(5) {
                scenario.moveToState(Lifecycle.State.CREATED)
                scenario.moveToState(Lifecycle.State.RESUMED)
                scenario.recreate()
                onView(withText(containsString("Renderer mount live")))
                    .perform(scrollTo())
                    .check(matches(isDisplayed()))
                onView(isAssignableFrom(EditText::class.java)).check { view, error ->
                    if (error != null) throw error
                    assertEquals("Crystal state must survive Activity recreation", "Draft notegoal", (view as EditText).text.toString())
                }
                assertEquals("Recreation must not accumulate references or callbacks", mountedCounts, nativeCounts())
            }
        } finally {
            scenario.close()
        }

        val releasedCounts = nativeCounts()
        assertEquals("Activity teardown should release every JNI global reference", 0, releasedCounts.globalReferences)
        assertEquals("Activity teardown should unregister every Crystal callback", 0, releasedCounts.callbacks)
    }

    private companion object {
        const val KEYSTROKE_SETTLE_MS = 300L
        const val UI_TIMEOUT_MS = 5_000L
    }
}
