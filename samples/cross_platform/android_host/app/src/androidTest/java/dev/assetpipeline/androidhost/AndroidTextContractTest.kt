package dev.assetpipeline.androidhost

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.BaseInputConnection
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.*
import androidx.test.espresso.assertion.ViewAssertions.matches
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
class AndroidTextContractTest {
    private external fun collectionsNative(): Map<String, String>?
    private fun described(root: View, id: String): View? {
        if (NativeSemantics.testId(root) == id) return root
        if (root is ViewGroup) for (index in 0 until root.childCount) described(root.getChildAt(index), id)?.let { return it }
        return null
    }
    private fun firstEditor(root: View): EditText? {
        if (root is EditText) return root
        if (root is ViewGroup) for (index in 0 until root.childCount) firstEditor(root.getChildAt(index))?.let { return it }
        return null
    }
    private fun editor(activity: MainActivity, id: String) = requireNotNull(firstEditor(requireNotNull(described(activity.window.decorView, id))))
    private fun editorMatcher(id: String) = allOf(isAssignableFrom(EditText::class.java), isDescendantOfA(NativeTestIds.withTestId(id)))
    // The host defers a whole-tree refresh by 250ms after recreation. A tap
    // that lands before it focuses an editor the refresh then replaces, and
    // the replacement has no focus (CI run 21, API 31). Wait until the tree
    // has reported the same editor instance for longer than that deferral.
    private fun awaitSettledEditor(scenario: ActivityScenario<MainActivity>, id: String) {
        val deadline = android.os.SystemClock.uptimeMillis() + 5000L
        var last: EditText? = null
        var stableSince = 0L
        while (android.os.SystemClock.uptimeMillis() < deadline) {
            var now: EditText? = null
            scenario.onActivity { activity -> now = editor(activity, id) }
            if (now != null && now === last) {
                if (stableSince == 0L) stableSince = android.os.SystemClock.uptimeMillis()
                if (android.os.SystemClock.uptimeMillis() - stableSince >= 400L) return
            } else stableSince = 0L
            last = now
            android.os.SystemClock.sleep(50L)
        }
        throw AssertionError("Editor $id did not settle after recreation")
    }

    private fun publishExternalEdit(editor: EditText) {
        // The test's direct InputConnection is not the system IME's session.
        // Notify that session after our main-thread transaction, before its
        // queued requests can act on obsolete surrounding text/composing ranges.
        // finishComposingText alone only removes spans in the local editor.
        // This is test-input coordination, not a production per-keystroke reset.
        val keyboard = editor.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        if (Build.VERSION.SDK_INT >= 33) keyboard.invalidateInput(editor)
        else keyboard.restartInput(editor)
    }

    @Test fun unicodeCompositionSubmitAndMultilineStateSurviveRecreation() {
        val initial = "A\u0000雪 😀 e\u0301 👩🏽‍💻 مرحبا"
        val finalText = "Before\u0000After 雪 😀 e\u0301 👩🏽‍💻 مرحبا"
        val context = ApplicationProvider.getApplicationContext<Context>()
        val intent = Intent(context, MainActivity::class.java).apply {
            // Exercise the real Java -> Crystal route decoder, including NUL.
            putExtra(MainActivity.EXTRA_APP_SLUG, "text/雪😀\u0000end")
        }
        val scenario = ActivityScenario.launch<MainActivity>(intent)
        var counts: CrystalBridge.NativeDebugCounts? = null
        // This fixture contains only the synthetic strings declared above.
        // Retain a bounded failure-only trace to distinguish our explicit
        // InputConnection transactions from concurrent system IME edits.
        // This never adds editor text to normal application telemetry.
        val inputTrace = ArrayList<String>()
        try {
            scenario.onActivity { activity ->
                assertEquals(initial, (described(activity.window.decorView, "unicode-heading") as TextView).text.toString())
                assertEquals(initial, editor(activity, "unicode-field").text.toString())
                assertNull(editor(activity, "unicode-readonly").keyListener)
                assertEquals("Read only 雪 😀", editor(activity, "unicode-readonly").text.toString())
                counts = CrystalBridge.debugCounts()
                assertEquals(mapOf("key\u0000雪😀" to "value\u0000e\u0301👩🏽‍💻"), collectionsNative())
                val traced = editor(activity, "unicode-field")
                traced.addTextChangedListener(object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) { }
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) { }
                    override fun afterTextChanged(s: Editable?) {
                        val changed = s ?: return
                        val origin = Throwable().stackTrace.filter { frame ->
                            frame.className.contains("InputConnection") || frame.className.contains("AndroidTextContractTest")
                        }.take(12).joinToString(" <- ") { "${it.className}.${it.methodName}:${it.lineNumber}" }
                        val text = changed.toString().replace("\u0000", "\\0").replace("\n", "\\n")
                        synchronized(inputTrace) {
                            if (inputTrace.size == 32) inputTrace.removeAt(0)
                            inputTrace.add("${android.os.SystemClock.uptimeMillis()} text=$text selection=${traced.selectionStart}:${traced.selectionEnd} composing=${BaseInputConnection.getComposingSpanStart(changed)}:${BaseInputConnection.getComposingSpanEnd(changed)} origin=$origin")
                        }
                    }
                })
            }
            onView(editorMatcher("unicode-field")).perform(scrollTo(), click())
            scenario.onActivity { activity ->
                val field = editor(activity, "unicode-field")
                assertTrue(field.hasFocus())
                val info = EditorInfo()
                val connection = requireNotNull(field.onCreateInputConnection(info))
                assertEquals(EditorInfo.IME_ACTION_DONE, info.imeOptions and EditorInfo.IME_MASK_ACTION)
                assertTrue(connection.beginBatchEdit())
                // The real keyboard may mark the tapped word as composing.
                // End that transaction before selecting all for this new one;
                // setComposingText replaces an existing composing span before
                // considering the selection. Do not rewrite the field's text.
                assertTrue(connection.finishComposingText())
                assertEquals(initial, field.text.toString())
                assertEquals(-1, BaseInputConnection.getComposingSpanStart(field.text))
                assertTrue(connection.setSelection(0, field.text.length))
                assertEquals(0, field.selectionStart)
                assertEquals(field.text.length, field.selectionEnd)
                assertTrue(connection.setComposingText("か", 1))
                assertEquals(0, BaseInputConnection.getComposingSpanStart(field.text))
                assertEquals(1, BaseInputConnection.getComposingSpanEnd(field.text))
                assertTrue(connection.setComposingText("漢字 😀", 1))
                assertEquals("漢字 😀", field.text.toString())
                assertEquals("漢字 😀".length, BaseInputConnection.getComposingSpanEnd(field.text))
                assertTrue(connection.commitText(finalText, 1))
                connection.endBatchEdit()
                assertEquals(finalText, field.text.toString())
                assertEquals(-1, BaseInputConnection.getComposingSpanStart(field.text))
                assertEquals(finalText.length, field.selectionStart)
                assertEquals(finalText.length, field.selectionEnd)
                // Code-point deletion must remove one supplementary character,
                // not half its UTF-16 pair or part of the preceding ZWJ text.
                assertTrue(connection.commitText("🙂", 1))
                assertTrue(connection.deleteSurroundingTextInCodePoints(1, 0))
                assertEquals(finalText, field.text.toString())
                assertSame("Composition callbacks cannot replace the editor", field, editor(activity, "unicode-field"))
                assertTrue(field.hasFocus())
                assertEquals(counts, CrystalBridge.debugCounts())
                assertTrue(connection.performEditorAction(EditorInfo.IME_ACTION_DONE))
                publishExternalEdit(field)
            }
            // The host deliberately defers whole-tree refresh by 250ms.
            // Espresso's immediate assertion can capture the old TextView.
            // A state-preserving refresh keeps the editor/keyboard in view;
            // the submit label may legitimately remain below the viewport.
            // Wait for actual native text, not a forced scroll-to-top side effect.
            val submitDeadline = android.os.SystemClock.uptimeMillis() + 5000L
            var submitted = false
            while (!submitted && android.os.SystemClock.uptimeMillis() < submitDeadline) {
                scenario.onActivity { activity -> submitted = (described(activity.window.decorView, "unicode-submits") as? TextView)?.text?.toString() == "Submits: 1" }
                if (!submitted) android.os.SystemClock.sleep(25L)
            }
            assertTrue("Native submit result must update", submitted)
            onView(NativeTestIds.withTestId("unicode-submits")).check(matches(withText("Submits: 1")))
            scenario.onActivity { activity ->
                assertEquals(finalText, (described(activity.window.decorView, "unicode-state") as TextView).text.toString())
                assertEquals(finalText, (described(activity.window.decorView, "unicode-submitted") as TextView).text.toString())
                assertEquals("valid=true bytes=${finalText.toByteArray(Charsets.UTF_8).size}", (described(activity.window.decorView, "unicode-validity") as TextView).text.toString())
                assertEquals(counts, CrystalBridge.debugCounts())
            }
            scenario.recreate()
            scenario.onActivity { activity -> assertEquals(finalText, editor(activity, "unicode-field").text.toString()) }
            awaitSettledEditor(scenario, "unicode-multiline")
            onView(editorMatcher("unicode-multiline")).perform(scrollTo(), click())
            scenario.onActivity { activity ->
                val multiline = editor(activity, "unicode-multiline")
                assertTrue(multiline.hasFocus())
                val connection = requireNotNull(multiline.onCreateInputConnection(EditorInfo()))
                assertTrue(connection.finishComposingText())
                assertTrue(connection.setSelection(0, multiline.text.length))
                assertTrue(connection.commitText("Alpha\nBeta 雪 😀", 1))
                assertEquals("Alpha\nBeta 雪 😀", multiline.text.toString())
                publishExternalEdit(multiline)
            }
            onView(editorMatcher("unicode-multiline")).perform(closeSoftKeyboard())
            scenario.recreate()
            scenario.onActivity { activity ->
                assertEquals("Alpha\nBeta 雪 😀", editor(activity, "unicode-multiline").text.toString())
                assertEquals("Submits: 1", (described(activity.window.decorView, "unicode-submits") as TextView).text.toString())
                assertNull(editor(activity, "unicode-readonly").keyListener)
                assertEquals(counts, CrystalBridge.debugCounts())
            }
        } catch (failure: Throwable) {
            InstrumentationRegistry.getInstrumentation().sendStatus(0, Bundle().apply {
                putString("unicode_input_trace", synchronized(inputTrace) { inputTrace.joinToString("\n") })
            })
            throw failure
        } finally { scenario.close() }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            assertEquals(CrystalBridge.NativeDebugCounts(0, 0), CrystalBridge.debugCounts())
        }
    }
}
