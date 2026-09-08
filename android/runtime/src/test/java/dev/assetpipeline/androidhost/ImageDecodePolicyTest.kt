package dev.assetpipeline.androidhost

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ImageDecodePolicyTest {
    @Test fun aPhotoWithinTheBudgetDecodesAtFullSize() {
        assertEquals(1, ImageDecodePolicy.sampleSize(1200, 675))
        assertEquals(1, ImageDecodePolicy.sampleSize(1024, 1024))
        assertEquals(1, ImageDecodePolicy.sampleSize(64, 64))
    }

    @Test fun aProductPhotoJustOverTheBudgetHalves() {
        assertEquals(2, ImageDecodePolicy.sampleSize(1200, 900))
        assertEquals(2, ImageDecodePolicy.sampleSize(2048, 1024))
    }

    @Test fun aCameraPhotoSamplesUntilItFitsBothTheBudgetAndTheEdge() {
        assertEquals(4, ImageDecodePolicy.sampleSize(4032, 3024))
        assertEquals(2, ImageDecodePolicy.sampleSize(8000, 200))
        assertEquals(16, ImageDecodePolicy.sampleSize(12_000, 9000))
    }

    @Test fun anAbsurdDeclaredSizeIsRefused() {
        assertFalse(ImageDecodePolicy.accepts(0, 100))
        assertFalse(ImageDecodePolicy.accepts(100, 0))
        assertFalse(ImageDecodePolicy.accepts(16_385, 100))
        assertTrue(ImageDecodePolicy.accepts(16_384, 16_384))
        assertThrows(IllegalArgumentException::class.java) { ImageDecodePolicy.sampleSize(0, 0) }
    }
}
