package dev.assetpipeline.androidhost

import android.app.Activity
import android.content.Context
import android.graphics.Rect
import android.os.Bundle
import android.os.Looper
import android.util.Log
import android.view.inputmethod.BaseInputConnection
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout

/** One Activity-owned mount. Never retains an Activity or View in saved state. */
class NativeScreenHost(private val activity: Activity, private val mount: ViewGroup,
    private val viewport: View? = null, savedState: Bundle? = null) {
    companion object { private const val STATE = "asset_pipeline.native_view_state.v1" }
    private val history = ViewStatePolicy.History()
    private var pendingSaved = NativeViewState.fromBundle(NativeViewState.raw(NativeViewState.raw(savedState, STATE) as? Bundle, "current") as? Bundle)
    private var pendingRestore: ViewStatePolicy.Snapshot? = null
    private var restoreListener: ViewTreeObserver.OnPreDrawListener? = null
    private var restoreRoot: View? = null
    private var route: String? = null
    private var closed = false
    private val dialogs = NativeDialogHost(activity, savedState)
    private var registeredDialogs = false
    var deferredRefreshes = 0
        private set
    var restoredEntries = 0
        private set
    var skippedSnapshots = 0
        private set

    init {
        mount.isFocusableInTouchMode = true
        mount.descendantFocusability = ViewGroup.FOCUS_BEFORE_DESCENDANTS
        val bundles = NativeViewState.raw(NativeViewState.raw(savedState, STATE) as? Bundle, "history") as? ArrayList<*>
        if (bundles != null && bundles.size <= 8) {
            var bytes = 0
            for (bundle in bundles.asReversed()) {
                val saved = NativeViewState.fromBundle(bundle as? Bundle) ?: continue
                bytes += saved.entries.keys.sumOf { it.toByteArray(Charsets.UTF_8).size }
                if (bytes > 65_536) break
                history.remember(saved)
            }
        }
    }

    private fun main() = check(Looper.myLooper() == Looper.getMainLooper()) { "Native screen host requires the main looper" }
    private fun cancelRestore() {
        restoreListener?.let { listener -> restoreRoot?.viewTreeObserver?.takeIf { it.isAlive }?.removeOnPreDrawListener(listener) }
        restoreListener = null; restoreRoot = null
    }
    private fun capture(): ViewStatePolicy.Snapshot? = pendingRestore ?: pendingSaved ?: mount.getChildAt(0)?.let { root ->
        route?.let { withinBudget { NativeViewState.capture(root, it, viewport) } }
    }
    private fun <T> withinBudget(block: () -> T): T? = try { block() } catch (_: NativeViewState.BudgetExceeded) {
        skippedSnapshots++
        // No keys, route, exception message, editor text or Activity in logs.
        Log.w("APViewState", "View metadata limit reached; state restoration skipped")
        null
    }

    /** False means an asynchronous update is waiting for a real IME composition
     * to finish. The Activity retries while visible; explicit user actions can
     * commit to a replacement immediately. No partial native render is started.
     */
    fun render(nextRoute: String, userAction: Boolean = false): Boolean {
        main(); check(!closed)
        // Metadata-only hosts can validate/save bounded snapshots without
        // claiming a native surface. Enforce single-window ownership when
        // rendering is actually attempted, before replacing any live tree.
        if (!registeredDialogs) {
            CrystalBridge.installDialogs(activity, dialogs)
            registeredDialogs = true
        }
        val old = mount.getChildAt(0)
        val focused = dialogs.focusedEditor ?: (old?.findFocus() as? EditText)
        if (!userAction && route == nextRoute && focused != null &&
            BaseInputConnection.getComposingSpanStart(focused.text) >= 0) {
            deferredRefreshes++
            return false
        }
        val saved = if (route == null || route == nextRoute) capture() else null
        capture()?.let { history.remember(it) }
        if (route != null && route != nextRoute) pendingSaved = null
        cancelRestore()
        pendingRestore = saved
        route = nextRoute
        dialogs.beforeRender()
        mount.removeAllViews()
        mount.requestFocus()
        val root = try { requireNotNull(CrystalBridge.renderStudy(activity, nextRoute)) }
            catch (error: Throwable) { pendingSaved = null; pendingRestore = null; throw error }
        // Crystal owns field values. Suppress the framework's independent
        // hierarchy snapshot (including EditText text and unstable native IDs)
        // in favor of our bounded, metadata-only restoration contract.
        root.isSaveFromParentEnabled = false
        root.isSaveEnabled = false
        mount.addView(root, FrameLayout.LayoutParams(-1, -2))
        run {
            val listener = object : ViewTreeObserver.OnPreDrawListener {
                override fun onPreDraw(): Boolean {
                    cancelRestore()
                    if (closed || !root.isAttachedToWindow || mount.getChildAt(0) !== root) return true
                    if (CrystalBridge.debugSessionState() != HostSession.State.FOREGROUND) return true
                    val target = withinBudget { ViewStatePolicy.screen(NativeViewState.nodes(root).map { it.identity }) }
                    if (target == null) { pendingRestore = null; return true }
                    val chosen = pendingSaved?.takeIf { it.route == nextRoute && it.screen == target }
                        ?: history.find(nextRoute, target) ?: saved
                    val requested = NativeSemantics.applyFocusRequests(root)
                    val result = chosen?.let { NativeViewState.restore(root, nextRoute, it, viewport, restoreFocus = requested == null) } ?: (0 to null)
                    if (chosen == null || chosen.screen != target) viewport?.scrollTo(0, 0)
                    // Saved scroll offsets describe the previous presentation.
                    // A new explicit focus request takes precedence on every
                    // scrollable ancestor, including the two-axis viewport.
                    requested?.requestRectangleOnScreen(Rect(0, 0, requested.width, requested.height), true)
                    restoredEntries += result.first
                    pendingRestore = null
                    // An app may render a loading screen before asynchronous
                    // model restoration. Keep saved keyed identities until a
                    // matching stateful screen actually appears.
                    if (chosen === pendingSaved && (result.first > 0 || chosen?.entries?.isEmpty() == true)) pendingSaved = null
                    val editor = (requested as? EditText) ?: if (requested == null) result.second else null
                    if (editor != null && activity.hasWindowFocus()) {
                        val keyboard = activity.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                        if (chosen?.ime == true) keyboard.showSoftInput(editor, InputMethodManager.SHOW_IMPLICIT)
                        else keyboard.hideSoftInputFromWindow(editor.windowToken, 0)
                    }
                    CrystalBridge.synchronizeDialogs(dialogs, root, nextRoute)
                    return true
                }
            }
            restoreRoot = root; restoreListener = listener
            root.viewTreeObserver.addOnPreDrawListener(listener)
        }
        return true
    }
    fun saveState(outState: Bundle) {
        main(); check(!closed)
        dialogs.saveState(outState)
        capture()?.let { current ->
            history.remember(current)
            val state = withinBudget { Bundle().apply {
                putBundle("current", NativeViewState.toBundle(current))
                if (NativeViewState.encodedSize(this) > NativeViewState.MAX_SAVED_BYTES) throw NativeViewState.BudgetExceeded()
                var bytes = 0
                val bundles = ArrayList<Bundle>()
                for (saved in history.all()) {
                    bytes += saved.entries.keys.sumOf { it.toByteArray(Charsets.UTF_8).size }
                    if (bytes > 65_536) break
                    bundles.add(NativeViewState.toBundle(saved))
                    putParcelableArrayList("history", ArrayList(bundles))
                    if (NativeViewState.encodedSize(this) > NativeViewState.MAX_SAVED_BYTES) {
                        bundles.removeAt(bundles.lastIndex)
                        putParcelableArrayList("history", ArrayList(bundles))
                        break
                    }
                }
            } } ?: return
            outState.putBundle(STATE, state)
        }
    }
    fun close() {
        main()
        cancelRestore(); pendingSaved = null; pendingRestore = null
        history.clear()
        dialogs.close()
        CrystalBridge.removeDialogs(dialogs)
        closed = true
    }
}
