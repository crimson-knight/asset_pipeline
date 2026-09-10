package dev.assetpipeline.androidhost

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ViewportPolicyTest {
    private val density = 2.625f
    private val window = ViewportPolicy.Frame(0, 0, 1080, 2340)
    private val bars = ViewportPolicy.Edges(0, 63, 0, 126)
    private fun dp(pixels: Int) = pixels / density.toDouble()

    @Test fun aHostThatPadsByTheBarsReportsTheAreaInsideThemAndNoInsets() {
        val report = ViewportPolicy.report(window, 1080, 2340, bars, bars, 0, density)
        assertEquals(dp(1080), report.widthDp, 1e-9)
        assertEquals(dp(2340 - 63 - 126), report.heightDp, 1e-9)
        for (inset in listOf(report.topDp, report.bottomDp, report.leftDp, report.rightDp)) assertEquals(0.0, inset, 1e-9)
        assertEquals(density.toDouble(), report.density, 1e-9)
    }

    @Test fun anEdgeToEdgeHostReportsTheWholeWindowAndTheBarsAsInsets() {
        val report = ViewportPolicy.report(window, 1080, 2340, bars, ViewportPolicy.Edges.NONE, 0, density)
        assertEquals(dp(1080), report.widthDp, 1e-9)
        assertEquals(dp(2340), report.heightDp, 1e-9)
        assertEquals(dp(63), report.topDp, 1e-9)
        assertEquals(dp(126), report.bottomDp, 1e-9)
    }

    @Test fun keyboardPaddingBeyondTheBarsChangesNothing() {
        val hidden = ViewportPolicy.report(window, 1080, 2340, bars, bars, 0, density)
        val shown = ViewportPolicy.report(window, 1080, 2340, bars, ViewportPolicy.Edges(0, 63, 0, 126 + 800), 0, density)
        assertEquals(hidden, shown)
    }

    @Test fun aContainerBelowTheStatusBarOverlapsOnlyThePartInsideIt() {
        val frame = ViewportPolicy.Frame(0, 40, 1080, 2340)
        val report = ViewportPolicy.report(frame, 1080, 2340, bars, ViewportPolicy.Edges.NONE, 0, density)
        assertEquals(dp(23), report.topDp, 1e-9)
        assertEquals(dp(126), report.bottomDp, 1e-9)
        assertEquals(dp(2300), report.heightDp, 1e-9)
        assertEquals(ViewportPolicy.Edges(0, 0, 0, 0), ViewportPolicy.overlap(ViewportPolicy.Frame(0, 63, 1080, 2214), 1080, 2340, bars))
    }

    @Test fun sideBarsInLandscapeBecomeHorizontalInsetsUnlessPadded() {
        val landscape = ViewportPolicy.Frame(0, 0, 2340, 1080)
        val side = ViewportPolicy.Edges(0, 63, 126, 0)
        val open = ViewportPolicy.report(landscape, 2340, 1080, side, ViewportPolicy.Edges.NONE, 0, density)
        assertEquals(dp(126), open.rightDp, 1e-9)
        assertEquals(dp(2340), open.widthDp, 1e-9)
        val padded = ViewportPolicy.report(landscape, 2340, 1080, side, side, 0, density)
        assertEquals(0.0, padded.rightDp, 1e-9)
        assertEquals(dp(2340 - 126), padded.widthDp, 1e-9)
    }

    @Test fun aLaidOutMountWidthIsTheWidthTheTreeGets() {
        val report = ViewportPolicy.report(window, 1080, 2340, bars, bars, 900, density)
        assertEquals(dp(900), report.widthDp, 1e-9)
        assertEquals(dp(2340 - 63 - 126), report.heightDp, 1e-9)
    }

    @Test fun invalidGeometryIsRejected() {
        assertThrows(IllegalArgumentException::class.java) { ViewportPolicy.Edges(-1, 0, 0, 0) }
        assertThrows(IllegalArgumentException::class.java) { ViewportPolicy.Frame(10, 0, 0, 0) }
        assertThrows(IllegalArgumentException::class.java) { ViewportPolicy.report(window, 1080, 2340, bars, bars, 0, 0f) }
        assertThrows(IllegalArgumentException::class.java) { ViewportPolicy.report(window, 0, 2340, bars, bars, 0, density) }
        assertThrows(IllegalArgumentException::class.java) { ViewportPolicy.report(ViewportPolicy.Frame(0, 0, 0, 0), 1080, 2340, bars, bars, 0, density) }
    }
}
