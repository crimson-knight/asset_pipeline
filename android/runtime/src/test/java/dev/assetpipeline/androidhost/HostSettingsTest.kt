package dev.assetpipeline.androidhost

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HostSettingsTest {
    @After fun reset() = HostSettings.clear()

    @Test fun parsesKeyValueLinesAndSkipsCommentsBlanksAndMalformedLines() {
        val parsed = HostSettings.parse("# baked by the release script\n\nAGENTC_DEMO_ID = SroXj5aH\nAGENTC_DEMO_PALETTE=#1B7268,#FAED1F,#FFFFFF,#122220\nAGENTC_DEMO_API_BASE=https://quiltperfect.example/api?x=1\nno equals here\n=orphan\n  SPACED  =  a value with  spaces  \n")
        assertEquals(listOf("AGENTC_DEMO_ID", "AGENTC_DEMO_PALETTE", "AGENTC_DEMO_API_BASE", "SPACED"), parsed.keys.toList())
        assertEquals("SroXj5aH", parsed["AGENTC_DEMO_ID"])
        assertEquals("#1B7268,#FAED1F,#FFFFFF,#122220", parsed["AGENTC_DEMO_PALETTE"])
        assertEquals("https://quiltperfect.example/api?x=1", parsed["AGENTC_DEMO_API_BASE"])
        assertEquals("a value with  spaces", parsed["SPACED"])
    }

    @Test fun keysAndValuesAreBoundedAndLaterRegistrationsReplaceEarlierOnes() {
        assertTrue(HostSettings.register("AGENTC_DEMO_DISPLAY_NAME", "QuiltPerfect"))
        assertTrue(HostSettings.register("AGENTC_DEMO_DISPLAY_NAME", "Quilt Perfect"))
        assertEquals("Quilt Perfect", String(HostSettings.valueBytes("AGENTC_DEMO_DISPLAY_NAME".toByteArray())!!, Charsets.UTF_8))
        assertFalse(HostSettings.register("", "x"))
        assertFalse(HostSettings.register("has space", "x"))
        assertFalse(HostSettings.register("k".repeat(65), "x"))
        assertTrue(HostSettings.register("k".repeat(64), "x"))
        assertFalse(HostSettings.register("TOO_LONG", "v".repeat(4097)))
        assertTrue(HostSettings.register("LONG_ENOUGH", "v".repeat(4096)))
        assertNull(HostSettings.valueBytes("NEVER_SET".toByteArray()))
        assertEquals(2, HostSettings.registerSerialized("A=1\nbad key=2\nB=2\n"))
        assertEquals(listOf("A", "AGENTC_DEMO_DISPLAY_NAME", "B", "LONG_ENOUGH", "k".repeat(64)), HostSettings.keys())
    }

    @Test fun valuesRoundTripAsUtf8() {
        assertTrue(HostSettings.register("NAME", "Näh-Studio 雪 😀"))
        assertEquals("Näh-Studio 雪 😀", String(HostSettings.valueBytes("NAME".toByteArray(Charsets.UTF_8))!!, Charsets.UTF_8))
    }
}
