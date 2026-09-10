package dev.assetpipeline.androidhost

import android.graphics.Typeface
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FontPolicyTest {
    @Test fun familyNamesArePlainAndBounded() {
        assertTrue(FontPolicy.validFamily("Inter-SemiBold"))
        assertTrue(FontPolicy.validFamily("serif"))
        assertFalse(FontPolicy.validFamily(""))
        assertFalse(FontPolicy.validFamily(" "))
        assertFalse(FontPolicy.validFamily("a\tb"))
        assertFalse(FontPolicy.validFamily("x".repeat(129)))
    }
    @Test fun theSystemFamilyIsTheDefaultByEitherName() {
        assertTrue(FontPolicy.system("system"))
        assertTrue(FontPolicy.system(""))
        assertFalse(FontPolicy.system("serif"))
    }
    @Test fun aRegisteredFaceKeepsItsWeightAndTakesOnlyItalic() {
        assertEquals(Typeface.NORMAL, FontPolicy.registeredStyle(Typeface.BOLD))
        assertEquals(Typeface.ITALIC, FontPolicy.registeredStyle(Typeface.BOLD_ITALIC))
        assertEquals(Typeface.ITALIC, FontPolicy.registeredStyle(Typeface.ITALIC))
        assertEquals(Typeface.NORMAL, FontPolicy.registeredStyle(Typeface.NORMAL))
    }
}
