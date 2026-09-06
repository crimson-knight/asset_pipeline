package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class ViewStatePolicyTest {
    private fun id(key: String? = "field", scope: String = "page-a", path: String = "0.1", kind: String = "TextField") =
        ViewStatePolicy.Identity(kind, key, scope, path)
    private fun snapshot(ids: List<ViewStatePolicy.Identity>) = ViewStatePolicy.Snapshot("main", ViewStatePolicy.shape(ids),
        ViewStatePolicy.unique(ids).mapValues { (_, id) -> ViewStatePolicy.Value(id.key != null, true, 2, 4, 10f, 20f) }, true, 0f, 12f)
    @Test fun keysSurviveSiblingInsertionButUnkeyedPathsRequireTheSameWholeShape() {
        val keyed = id(); val unkeyed = id(null, path = "0.2")
        val saved = snapshot(listOf(keyed, unkeyed))
        assertEquals(2, ViewStatePolicy.match(saved, "main", listOf(keyed, unkeyed)).size)
        val changed = listOf(id("new", path = "0.0"), id(path = "0.2"), id(null, path = "0.3"))
        assertEquals(setOf(keyed.address), ViewStatePolicy.match(saved, "main", changed).keys)
    }
    @Test fun duplicateKeysAreAmbiguousInEitherOldOrNewTree() {
        val one = id(); val duplicate = id(path = "0.9")
        assertTrue(snapshot(listOf(one, duplicate)).entries.isEmpty())
        assertTrue(ViewStatePolicy.match(snapshot(listOf(one)), "main", listOf(one, duplicate)).isEmpty())
    }
    @Test fun routeScreenScopeAndKindPreventCrossScreenOrWrongWidgetRestoration() {
        val saved = snapshot(listOf(id()))
        assertTrue(ViewStatePolicy.match(saved, "other", listOf(id())).isEmpty())
        assertTrue(ViewStatePolicy.match(saved, "main", listOf(id(scope = "page-b"))).isEmpty())
        assertTrue(ViewStatePolicy.match(saved, "main", listOf(id(kind = "Label"))).isEmpty())
    }
    @Test fun identitiesRemainUnambiguousWithUnicodeAndDelimiterCharacters() {
        ViewStatePolicy.validateKey("雪😀\u0000:/")
        assertNotEquals(id("a:b", "c").address, id("b", "c:a").address)
        assertThrows(IllegalArgumentException::class.java) { ViewStatePolicy.validateKey("") }
        assertThrows(IllegalArgumentException::class.java) { ViewStatePolicy.validateKey("雪".repeat(86)) }
    }
    @Test fun invalidOrUnboundedStateIsNotRestored() {
        val saved = snapshot(listOf(id()))
        val broken = saved.copy(entries = mapOf(id().address to ViewStatePolicy.Value(true, true, Int.MAX_VALUE, 0, Float.NaN, 0f)))
        assertTrue(ViewStatePolicy.match(broken, "main", listOf(id())).isEmpty())
        assertThrows(IllegalArgumentException::class.java) { ViewStatePolicy.unique(List(1025) { id() }) }
    }
    @Test fun screenHistoryKeepsRecentScopesAndDoesNotShareMutableEntries() {
        val history = ViewStatePolicy.History()
        val entries = snapshot(listOf(id())).entries.toMutableMap()
        history.remember(snapshot(listOf(id())).copy(screen = "a", entries = entries))
        entries.clear()
        assertEquals(1, history.find("main", "a")!!.entries.size)
        assertNull(history.find("other", "a"))
        for (index in 0..8) history.remember(snapshot(listOf(id())).copy(screen = "page$index"))
        assertEquals(8, history.all().size)
        assertNull(history.find("main", "a")); assertNull(history.find("main", "page0"))
        history.remember(snapshot(listOf(id())).copy(screen = "page8", ime = false))
        assertEquals(8, history.all().size); assertFalse(history.find("main", "page8")!!.ime)
        history.clear(); assertTrue(history.all().isEmpty())
    }
}
