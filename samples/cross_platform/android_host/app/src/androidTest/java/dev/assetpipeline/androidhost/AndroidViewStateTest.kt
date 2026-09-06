package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Parcel
import android.os.Parcelable
import android.os.SystemClock
import android.util.SparseArray
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.BaseInputConnection
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.ScrollView
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.lifecycle.Lifecycle
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.*
import androidx.test.espresso.matcher.ViewMatchers.*
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.hamcrest.Matchers.allOf
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidViewStateTest {
    private fun find(root: View, id: String): View? {
        if (NativeSemantics.testId(root) == id) return root
        if (root is ViewGroup) for (index in 0 until root.childCount) find(root.getChildAt(index), id)?.let { return it }
        return null
    }
    private fun nodes(activity: MainActivity) = NativeViewState.nodes(activity.findViewById(R.id.rendererMount))
    private fun editor(activity: MainActivity) = requireNotNull(nodes(activity).single { NativeSemantics.testId(it.view) == "state-editor" }.editor)
    private fun scroll(activity: MainActivity) = find(activity.window.decorView, "state-scroll") as ScrollView
    private fun horizontal(activity: MainActivity) = scroll(activity).getChildAt(0) as HorizontalScrollView
    private fun awaitText(text: String) = assertTrue("Native text did not update", UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).wait(Until.hasObject(By.text(text)), 5000L))
    private fun launch(): ActivityScenario<MainActivity> {
        val context = ApplicationProvider.getApplicationContext<Context>()
        return ActivityScenario.launch(Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_APP_SLUG, "view-state"))
    }
    private fun contains(bytes: ByteArray, value: ByteArray): Boolean =
        value.isNotEmpty() && (0..bytes.size - value.size).any { offset -> value.indices.all { bytes[offset + it] == value[it] } }
    private fun hierarchyBytes(activity: MainActivity): ByteArray {
        val state = SparseArray<Parcelable>()
        activity.window.decorView.saveHierarchyState(state)
        val parcel = Parcel.obtain()
        return try { parcel.writeSparseArray(state); parcel.marshall() } finally { parcel.recycle() }
    }

    @Test fun compositionRefreshInsertionRecreationAndBackPreserveTheCorrectScreenState() {
        val scenario = launch()
        var old: EditText? = null
        var connection: InputConnection? = null
        var expectedX = 0; var expectedY = 0
        var beforeDeferred = 0
        try {
            awaitText("Page a")
            onView(allOf(isAssignableFrom(EditText::class.java), isDescendantOfA(NativeTestIds.withTestId("state-editor")))).perform(scrollTo(), click())
            scenario.onActivity { activity ->
                val field = editor(activity)
                old = field
                val input = requireNotNull(field.onCreateInputConnection(EditorInfo()))
                connection = input
                assertTrue(input.beginBatchEdit()); input.finishComposingText(); input.setSelection(0, field.text.length)
                // Keep the batch open across the asynchronous request so the
                // real IME cannot process our intermediate selection report
                // and finish this test-owned composition before the host runs.
                assertTrue(input.setComposingText("Composing 雪 😀", 1))
                assertEquals(0, BaseInputConnection.getComposingSpanStart(field.text))
                horizontal(activity).scrollTo(123, 0); scroll(activity).scrollTo(0, 234)
                expectedX = horizontal(activity).scrollX; expectedY = scroll(activity).scrollY
                assertTrue(expectedX > 0 && expectedY > 0)
                beforeDeferred = activity.debugViewStateCounts().first
                CrystalBridge.requestRender()
            }
            // The host deliberately coalesces requests for 250ms. Require its
            // deferred branch to have actually run, not just a pending timer.
            SystemClock.sleep(600L)
            scenario.onActivity { activity ->
                assertTrue(activity.debugViewStateCounts().first > beforeDeferred)
                assertSame(old, editor(activity))
                assertTrue(editor(activity).hasFocus())
                assertEquals(0, BaseInputConnection.getComposingSpanStart(editor(activity).text))
                assertTrue(requireNotNull(connection).finishComposingText())
                // EditText's final-batch return had an off-by-one through API
                // 32; Android documents its correction in API 33. End exactly
                // the one batch we opened, and retain all deferred-refresh,
                // composition, identity and selection assertions around it.
                assertEquals(android.os.Build.VERSION.SDK_INT < 33, requireNotNull(connection).endBatchEdit())
                editor(activity).setSelection(2, 4)
            }
            awaitText("Echo: Composing 雪 😀")
            scenario.onActivity { activity ->
                val field = editor(activity)
                assertNotSame("Completed composition permits the documented full-tree refresh", old, field)
                assertTrue(field.hasFocus()); assertEquals(2, field.selectionStart); assertEquals(4, field.selectionEnd)
                assertEquals(expectedX, horizontal(activity).scrollX); assertEquals(expectedY, scroll(activity).scrollY)
                assertTrue(activity.debugViewStateCounts().second >= 2)
            }
            onView(isAssignableFrom(EditText::class.java)).perform(closeSoftKeyboard())
            var expectedStructure = ""
            scenario.onActivity { activity ->
                val previous = (find(activity.window.decorView, "state-structure") as TextView).text.toString()
                expectedStructure = if (previous.endsWith("true")) "Structure: false" else "Structure: true"
            }
            onView(withText("Insert sibling")).perform(scrollTo(), click())
            try {
                awaitText(expectedStructure)
            } catch (failure: AssertionError) {
                // Failure-only diagnostics for this synthetic fixture: distinguish
                // a missed action from an updated label outside the viewport.
                scenario.onActivity { activity ->
                    val label = find(activity.window.decorView, "state-structure") as TextView
                    val rect = android.graphics.Rect()
                    val visible = label.getGlobalVisibleRect(rect)
                    val field = editor(activity)
                    InstrumentationRegistry.getInstrumentation().sendStatus(0, Bundle().apply {
                        putString("view_state_insertion", "expected=$expectedStructure actual=${label.text} visible=$visible rect=$rect inserted=${find(activity.window.decorView, "state-inserted") != null} hostScroll=${activity.findViewById<ScrollView>(R.id.hostViewport).scrollY} innerScroll=${horizontal(activity).scrollX}:${scroll(activity).scrollY} composing=${BaseInputConnection.getComposingSpanStart(field.text)}:${BaseInputConnection.getComposingSpanEnd(field.text)} focused=${field.hasFocus()} counts=${activity.debugViewStateCounts()}")
                    })
                }
                throw failure
            }
            scenario.onActivity { activity ->
                assertEquals(2, editor(activity).selectionStart); assertEquals(4, editor(activity).selectionEnd)
                assertEquals(expectedX, horizontal(activity).scrollX); assertEquals(expectedY, scroll(activity).scrollY)
            }
            scenario.moveToState(Lifecycle.State.CREATED)
            scenario.onActivity { activity ->
                val field = editor(activity)
                assertTrue("The stopped Activity's editor still owns native focus", field.hasFocus())
                assertFalse("This must exercise a hidden Activity window", field.isShown)
                val root = activity.findViewById<ViewGroup>(R.id.rendererMount).getChildAt(0)
                val captured = NativeViewState.capture(root, "view-state")
                val address = nodes(activity).single { it.editor === field }.identity.address
                assertNotNull("Window visibility must not discard the mounted editor's presentation state", captured.entries[address])
                assertTrue(captured.entries.getValue(address).focused)
            }
            scenario.moveToState(Lifecycle.State.RESUMED)
            awaitText("Echo: Composing 雪 😀")
            scenario.onActivity { activity ->
                assertTrue(editor(activity).hasFocus())
                assertEquals(2, editor(activity).selectionStart); assertEquals(4, editor(activity).selectionEnd)
                assertEquals(expectedX, horizontal(activity).scrollX); assertEquals(expectedY, scroll(activity).scrollY)
            }
            scenario.recreate()
            awaitText("Echo: Composing 雪 😀")
            scenario.onActivity { activity ->
                assertTrue(editor(activity).hasFocus())
                assertEquals(2, editor(activity).selectionStart); assertEquals(4, editor(activity).selectionEnd)
                assertEquals(expectedX, horizontal(activity).scrollX); assertEquals(expectedY, scroll(activity).scrollY)
            }
            onView(withText("Open B")).perform(scrollTo(), click())
            awaitText("Page b")
            scenario.onActivity { activity ->
                assertEquals("Other screen text", editor(activity).text.toString())
                assertFalse("An identical key on a different screen must not inherit focus", editor(activity).hasFocus())
                assertEquals(0, horizontal(activity).scrollX); assertEquals(0, scroll(activity).scrollY)
            }
            UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).pressBack()
            awaitText("Page a")
            scenario.onActivity { activity ->
                assertEquals(2, editor(activity).selectionStart); assertEquals(4, editor(activity).selectionEnd)
                assertEquals(expectedX, horizontal(activity).scrollX); assertEquals(expectedY, scroll(activity).scrollY)
            }
        } finally { scenario.close() }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
        }
    }

    @Test fun savedStateContainsBoundedValuesAndRejectsMalformedBundles() {
        val scenario = launch()
        try {
            awaitText("Page a")
            scenario.onActivity { activity ->
                val root = activity.findViewById<ViewGroup>(R.id.rendererMount)
                val field = editor(activity)
                val entered = field.text.toString()
                val utf8 = entered.toByteArray(Charsets.UTF_8)
                val utf16 = entered.toByteArray(Charsets.UTF_16LE)
                assertTrue(entered.length > 8)
                val ownedRoot = root.getChildAt(0)
                assertFalse(ownedRoot.isSaveFromParentEnabled)
                // A positive control proves the byte check detects Android's
                // actual EditText saved text, not merely Bundle.toString().
                field.id = View.generateViewId()
                field.freezesText = true
                ownedRoot.isSaveFromParentEnabled = true
                try {
                    val frameworkCopy = hierarchyBytes(activity)
                    assertTrue(contains(frameworkCopy, utf8) || contains(frameworkCopy, utf16))
                } finally { ownedRoot.isSaveFromParentEnabled = false }
                val frameworkState = hierarchyBytes(activity)
                assertFalse(contains(frameworkState, utf8)); assertFalse(contains(frameworkState, utf16))
                val snapshot = NativeViewState.capture(root, "view-state")
                assertTrue(snapshot.entries.size >= 2)
                val saved = NativeViewState.toBundle(snapshot)
                val parcel = Parcel.obtain()
                val copied = try {
                    parcel.writeBundle(saved)
                    assertTrue("Saved view metadata must stay bounded", parcel.dataSize() < 65_536)
                    assertFalse(contains(parcel.marshall(), utf8)); assertFalse(contains(parcel.marshall(), utf16))
                    parcel.setDataPosition(0)
                    requireNotNull(parcel.readBundle(javaClass.classLoader))
                } finally { parcel.recycle() }
                assertEquals(snapshot, NativeViewState.fromBundle(copied))
                val bad = Bundle(saved).apply { putFloat("x", Float.NaN) }
                assertNull(NativeViewState.fromBundle(bad))
                assertNull(NativeViewState.fromBundle(Bundle(saved).apply { putString("shape", "invalid") }))
                assertNull(NativeViewState.fromBundle(Bundle(saved).apply { putString("version", "AP_PRIVATE_VIEW_STATE_MALFORMED_SENTINEL") }))
                assertNull(NativeViewState.fromBundle(Bundle(saved).apply { putIntegerArrayList("keys", arrayListOf(123)) }))
                assertNull(NativeViewState.fromBundle(Bundle(saved).apply { putString("ime", "AP_PRIVATE_VIEW_STATE_MALFORMED_SENTINEL") }))
                assertNull(NativeViewState.fromBundle(Bundle(saved).apply { remove("x") }))
                assertNull(NativeViewState.fromBundle(Bundle(saved).apply { putByteArray("unexpected", ByteArray(NativeViewState.MAX_SAVED_BYTES)) }))
                assertThrows(NativeViewState.BudgetExceeded::class.java) {
                    NativeViewState.toBundle(snapshot.copy(route = "x".repeat(4097)))
                }
                // Exercise actual Parcel size, including nested Bundle overhead
                // and eight histories, not only the sum of UTF-8 key lengths.
                val dense = snapshot.copy(entries = (0 until 256).associate {
                    "$it:" + "k".repeat(110) to ViewStatePolicy.Value(true, false, 0, 0, 0f, 0f)
                })
                val incoming = Bundle().apply {
                    putBundle("asset_pipeline.native_view_state.v1", Bundle().apply {
                        putBundle("current", NativeViewState.toBundle(dense))
                        putParcelableArrayList("history", ArrayList((0..7).map {
                            NativeViewState.toBundle(dense.copy(screen = "%064x".format(it)))
                        }))
                    })
                }
                val isolated = NativeScreenHost(activity, android.widget.FrameLayout(activity), savedState = incoming)
                val bounded = Bundle()
                try { isolated.saveState(bounded) } finally { isolated.close() }
                val state = requireNotNull(bounded.getBundle("asset_pipeline.native_view_state.v1"))
                assertTrue(NativeViewState.encodedSize(state) <= NativeViewState.MAX_SAVED_BYTES)
                assertEquals(dense, NativeViewState.fromBundle(state.getBundle("current")))
                val tagged = nodes(activity).single { it.editor === field }
                tagged.view.visibility = View.INVISIBLE
                assertFalse(NativeViewState.capture(root, "view-state").entries.containsKey(tagged.identity.address))
                tagged.view.visibility = View.VISIBLE
                val parent = tagged.view.parent as View
                parent.visibility = View.GONE
                assertFalse(NativeViewState.capture(root, "view-state").entries.containsKey(tagged.identity.address))
                parent.visibility = View.VISIBLE
                tagged.view.isEnabled = false
                assertFalse(NativeViewState.capture(root, "view-state").entries.containsKey(tagged.identity.address))
                tagged.view.isEnabled = true
                field.transformationMethod = android.text.method.PasswordTransformationMethod.getInstance()
                field.setSelection(2, 4)
                val sensitive = NativeViewState.capture(root, "view-state")
                val key = nodes(activity).single { it.editor === field }.identity.address
                assertTrue(sensitive.entries.getValue(key).sensitive)
                val restored = requireNotNull(NativeViewState.fromBundle(NativeViewState.toBundle(sensitive)))
                assertEquals(-1, restored.entries.getValue(key).start)
                assertEquals(-1, restored.entries.getValue(key).end)
            }
        } finally { scenario.close() }
    }

    @Test fun oversizedNativeMetadataFallsBackToAnOrdinaryRefreshWithoutRetainingTheOldTree() {
        val scenario = launch()
        var old: EditText? = null
        try {
            awaitText("Page a")
            scenario.onActivity { activity ->
                old = editor(activity)
                val root = activity.findViewById<ViewGroup>(R.id.rendererMount).getChildAt(0) as ViewGroup
                repeat(ViewStatePolicy.MAX_NODES + 1) {
                    val extra = View(activity)
                    NativeViewState.mark(extra, "", "BudgetFixture", "")
                    root.addView(extra)
                }
                assertThrows(NativeViewState.BudgetExceeded::class.java) { NativeViewState.capture(root, "view-state") }
                CrystalBridge.requestRender()
            }
            val deadline = SystemClock.uptimeMillis() + 5000L
            var refreshed = false
            while (!refreshed && SystemClock.uptimeMillis() < deadline) {
                scenario.onActivity { activity ->
                    if (activity.debugSkippedViewState() > 0) {
                        assertNotSame(old, editor(activity))
                        assertEquals(0, CrystalBridge.debugPendingServices().first)
                        refreshed = true
                    }
                }
                if (!refreshed) SystemClock.sleep(25L)
            }
            assertTrue("Bounded state fallback must be observable and complete the refresh", refreshed)
        } finally { scenario.close() }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
        }
    }
}
