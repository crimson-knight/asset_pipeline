package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class LayoutPolicyTest {
    @Test fun unspecifiedFixedAndBoundedAxesRemainDistinct() {
        assertFalse(LayoutPolicy.Axis().fixed)
        assertFalse(LayoutPolicy.Axis().needsBounds)
        assertTrue(LayoutPolicy.Axis(0f, 0f).fixed)
        assertFalse(LayoutPolicy.Axis(48.5f, 48.5f).needsBounds)
        assertTrue(LayoutPolicy.Axis(-1f, 128f).needsBounds)
        assertTrue(LayoutPolicy.Axis(64f, 128f).needsBounds)
    }
    @Test fun invalidDimensionsFailBeforeViewMutation() {
        for (bad in listOf(Float.NaN, Float.POSITIVE_INFINITY, Float.NEGATIVE_INFINITY, -0.5f, -2f, 1_000_001f)) {
            assertThrows(IllegalArgumentException::class.java) { LayoutPolicy.Axis(bad, -1f) }
            assertThrows(IllegalArgumentException::class.java) { LayoutPolicy.Axis(-1f, bad) }
        }
        assertThrows(IllegalArgumentException::class.java) { LayoutPolicy.Axis(100f, 99f) }
    }
    @Test fun FractionalDpIsRoundedOnlyAfterDensityConversion() {
        assertEquals(11, LayoutPolicy.pixels(10.5f, 1f))
        assertEquals(21, LayoutPolicy.pixels(10.5f, 2f))
        assertEquals(8, LayoutPolicy.pixels(5.5f, 1.5f))
        assertEquals(0, LayoutPolicy.pixels(0f, 3f))
    }
    @Test fun invalidDensityAndMeasureOverflowAreRejected() {
        for (density in listOf(0f, -1f, Float.NaN, Float.POSITIVE_INFINITY))
            assertThrows(IllegalArgumentException::class.java) { LayoutPolicy.pixels(1f, density) }
        assertThrows(IllegalArgumentException::class.java) { LayoutPolicy.pixels(1_000_000f, 10_000f) }
    }
}
