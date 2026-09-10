package dev.assetpipeline.androidhost

import android.content.res.Configuration
import org.junit.Assert.assertEquals
import org.junit.Test

class HostAppearanceTest {
    private fun configuration(uiMode: Int) = Configuration().apply { this.uiMode = uiMode }

    @Test fun nightYesIsDarkAndEverythingElseIsLight() {
        assertEquals(HostAppearance.DARK, HostAppearance.of(configuration(Configuration.UI_MODE_NIGHT_YES or Configuration.UI_MODE_TYPE_NORMAL)))
        assertEquals(HostAppearance.LIGHT, HostAppearance.of(configuration(Configuration.UI_MODE_NIGHT_NO or Configuration.UI_MODE_TYPE_NORMAL)))
        assertEquals(HostAppearance.LIGHT, HostAppearance.of(configuration(Configuration.UI_MODE_NIGHT_UNDEFINED)))
    }

    @Test fun unknownBeforeAnyContext() {
        assertEquals(HostAppearance.UNKNOWN, HostAppearance.dark())
    }
}
