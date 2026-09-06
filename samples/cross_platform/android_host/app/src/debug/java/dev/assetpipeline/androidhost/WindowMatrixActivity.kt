package dev.assetpipeline.androidhost

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList

/** Debug-only configuration context. Exercises the real host lifecycle/window
 * without changing the device's global font scale, locale or display density.
 * Instrumentation owns the value and restores it after each closed scenario.
 */
class WindowMatrixActivity : MainActivity() {
    data class Profile(val fontScale: Float = 1f, val language: String = "en")
    companion object { @Volatile var profile = Profile() }
    override fun attachBaseContext(newBase: Context) {
        val selected = profile
        require(selected.fontScale in 1f..2f && selected.language in listOf("en", "ar"))
        // Override only the dimensions owned by this test. Copying the whole
        // base configuration also pins orientation/window-size fields.
        val configuration = Configuration().apply {
            fontScale = selected.fontScale
            setLocales(LocaleList.forLanguageTags(selected.language))
        }
        super.attachBaseContext(newBase.createConfigurationContext(configuration))
    }
}
