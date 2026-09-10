package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.graphics.Color
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.google.android.material.textfield.TextInputLayout
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.Assert.assertTrue
import org.junit.runner.RunWith

/** Text field styles: the rounded field keeps the Material filled box, the
 * underline field keeps only the indicator on a transparent box, the plain
 * field has no box, and an explicit placeholder color is the hint color. */
@RunWith(AndroidJUnit4::class)
class AndroidTextFieldStyleContractTest {
    @Test fun eachStyleReachesTheTextInputLayoutAndThePlaceholderColorIsTheHintColor() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val scenario = ActivityScenario.launch<MainActivity>(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "text-field-styles"))
        try {
            assertTrue("Native text did not appear", UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text("Native field styles")), 10000L))
            scenario.onActivity { activity ->
                val decor = activity.window.decorView
                fun layout(id: String): TextInputLayout {
                    var view = requireNotNull(NativeTestIds.find(decor, id)) { "missing $id" }
                    while (view !is TextInputLayout) view = view.parent as android.view.View
                    return view
                }
                val ink = Color.argb(255, (0.2 * 255).roundToInt(), (0.4 * 255).roundToInt(), (0.6 * 255).roundToInt())
                val rounded = layout("field-rounded")
                assertEquals("rounded keeps the filled box", TextInputLayout.BOX_BACKGROUND_FILLED, rounded.boxBackgroundMode)
                assertNotEquals("rounded keeps the Material hint color", ink, rounded.hintTextColor?.defaultColor)
                val underline = layout("field-underline")
                assertEquals("underline drops the box too: a filled box layers its color over the surface", TextInputLayout.BOX_BACKGROUND_NONE, underline.boxBackgroundMode)
                val plain = layout("field-plain")
                assertEquals("plain has no box", TextInputLayout.BOX_BACKGROUND_NONE, plain.boxBackgroundMode)
                assertEquals("the brand placeholder color is the hint color", ink, plain.hintTextColor?.defaultColor)
                assertEquals("Plain, brand placeholder", plain.hint.toString())
            }
        } finally { scenario.close() }
    }
}
