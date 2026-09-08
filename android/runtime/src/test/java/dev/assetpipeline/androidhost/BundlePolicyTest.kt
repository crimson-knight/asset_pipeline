package dev.assetpipeline.androidhost

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BundlePolicyTest {
    @Test fun theStampChangesWithTheVersionOrTheInstallTime() {
        assertEquals("7:1700000000000", BundlePolicy.stamp(7L, 1_700_000_000_000L))
        assertTrue(BundlePolicy.stamp(7L, 1L) != BundlePolicy.stamp(8L, 1L))
        assertTrue(BundlePolicy.stamp(7L, 1L) != BundlePolicy.stamp(7L, 2L))
    }
    @Test fun onlyPlainNamesInsideTheBundleRootAreExtracted() {
        assertTrue(BundlePolicy.validName("ap_bundle/fonts/Inter_semibold.ttf"))
        assertTrue(BundlePolicy.validName("ap_bundle/art/mark@2x.png"))
        for (bad in listOf("", "fonts/x.ttf", "ap_bundle/../x", "ap_bundle/./x", "ap_bundle//x", "/ap_bundle/x",
            "ap_bundle/a\\b", "ap_bundle/a b", "ap_bundle/" + "x".repeat(1100)))
            assertFalse(bad, BundlePolicy.validName(bad))
    }
    @Test fun onlyFilesInsideThePrivateDataDirectoryMayBeLoaded() {
        assertTrue(BundlePolicy.insideStorage("/data/user/0/app/files/asset_pipeline_bundle/ap_bundle/a.png", "/data/user/0/app"))
        assertFalse(BundlePolicy.insideStorage("/data/user/0/app", "/data/user/0/app"))
        assertFalse(BundlePolicy.insideStorage("/data/user/0/apple/x.png", "/data/user/0/app"))
        assertFalse(BundlePolicy.insideStorage("/system/fonts/Roboto-Regular.ttf", "/data/user/0/app"))
        assertFalse(BundlePolicy.insideStorage("/data/user/0/app/x", ""))
    }
    @Test fun theNameDeclaresTheDensityTheIosWay() {
        assertEquals(480, BundlePolicy.densityFor("mark@3x.png"))
        assertEquals(320, BundlePolicy.densityFor("mark@2x.png"))
        assertEquals(160, BundlePolicy.densityFor("mark.png"))
        assertEquals(160, BundlePolicy.densityFor("photo@2x.original.jpg"))
    }
}
