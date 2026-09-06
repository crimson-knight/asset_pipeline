package dev.assetpipeline.androidhost

import android.app.Activity
import android.content.Context
import android.graphics.Rect
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.AbsSeekBar
import android.widget.FrameLayout
import android.widget.LinearLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.widget.NestedScrollView
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.bottomsheet.BottomSheetDragHandleView
import org.json.JSONObject

/** Children are owned by the Crystal tree but mounted in a separate window. */
class NativeSheetAnchor(context: Context) : FrameLayout(context) {
    var descriptor: SheetPolicy.Descriptor? = null
        internal set
    init { visibility = GONE; isSaveEnabled = false; isSaveFromParentEnabled = false }
}

private const val DEBUG_TAG = "AssetPipelineSheet"
private const val RESTORE_CONFIRM_DELAY_MS = 900L
private const val RESTORE_CONFIRM_ATTEMPTS = 5

object NativeSheets {
    @JvmStatic fun configure(anchor: View, packet: String) {
        check(Looper.myLooper() == Looper.getMainLooper())
        require(anchor is NativeSheetAnchor && packet.toByteArray(Charsets.UTF_8).size <= 32_768)
        anchor.descriptor = try {
            val json = JSONObject(packet)
            require(json.length() == 8 && json.get("version") == 1)
            val values = json.getJSONArray("detents")
            require(values.length() in 1..3)
            fun token(value: Any): Long { require(value is Int || value is Long); return (value as Number).toLong() }
            SheetPolicy.validate(SheetPolicy.Descriptor(json.get("title") as String,
                (0 until values.length()).map { values.get(it) as Int }, json.get("selected") as Int,
                json.get("drag") as Boolean, json.get("locked") as Boolean,
                token(json.get("lifecycle")), token(json.get("detent"))))
        } catch (_: Exception) { throw IllegalArgumentException("Invalid Android sheet descriptor") }
    }
    @JvmStatic fun requestDismiss(anchor: View) {
        check(Looper.myLooper() == Looper.getMainLooper())
        require(anchor is NativeSheetAnchor)
        CrystalBridge.requestSheetDismiss(anchor)
    }
}

private class SheetWindow(context: Context, private val content: View) : BottomSheetDialog(context,
    context.resources.getIdentifier("APNativeSheetDialog", "style", context.packageName).also {
        check(it != 0) { "Host must include canonical native sheet resources" }
    }) {
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        // Material applies its inset policy here, potentially after show()
        // has returned. Establish our sole ownership after that actual hook.
        CrystalBridge.windowMutation {
            window?.let { WindowCompat.setDecorFitsSystemWindows(it, false) }
            for (id in listOf(com.google.android.material.R.id.container, com.google.android.material.R.id.coordinator)) {
                requireNotNull(findViewById<View>(id)).apply {
                    fitsSystemWindows = false
                    setPadding(0, 0, 0, 0)
                }
            }
        }
    }
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.hasNoModifiers() && NativeSemantics.dispatchShortcut(content, event, unmodifiedOnly = true)) return true
        return super.dispatchKeyEvent(event)
    }
    override fun dispatchKeyShortcutEvent(event: KeyEvent): Boolean =
        NativeSemantics.dispatchShortcut(content, event) || super.dispatchKeyShortcutEvent(event)
}

/** Activity-owned window, metadata-only saved state, no global View registry. */
class NativeSheetHost(private val activity: Activity, savedState: Bundle?) {
    companion object { private const val STATE = "asset_pipeline.native_sheet.v1" }
    private class Presented(val dialog: BottomSheetDialog, val anchor: NativeSheetAnchor,
        val content: View, val shell: LinearLayout, val viewport: NestedScrollView, val descriptor: SheetPolicy.Descriptor,
        val identity: String, val nodes: List<NativeViewState.Node>, val lease: DialogPolicy.Lease = DialogPolicy.Lease()) {
        var restored = false
        var imeAnimating = false
        var pending: Runnable? = null
        var draw: ViewTreeObserver.OnPreDrawListener? = null
        var windowFocus: ViewTreeObserver.OnWindowFocusChangeListener? = null
        var behaviorCallback: BottomSheetBehavior.BottomSheetCallback? = null
        var frame: FrameLayout? = null
        var geometry: SheetPolicy.Geometry? = null
        var insets: WindowInsetsCompat? = null
        var revealFocus = false
    }
    private val handler = Handler(Looper.getMainLooper())
    private var current: Presented? = null
    private var retiredIdentity: String? = null
    private var snapshot = NativeViewState.fromBundle(NativeViewState.raw(savedState, STATE) as? Bundle)
    val activeCount: Int get() = if (current?.lease?.active == true) 1 else 0
    val focusedEditor: EditText? get() = current?.content?.findFocus() as? EditText
    private fun main() = check(Looper.myLooper() == Looper.getMainLooper())
    private fun event(shown: Presented, action: () -> Unit) {
        if (current !== shown || !shown.lease.active) return
        CrystalBridge.windowMutation(action)
    }
    private fun capture() {
        val shown = current ?: return
        if (!shown.restored) return
        android.util.Log.d(DEBUG_TAG, "capture imeNow=${ViewCompat.getRootWindowInsets(shown.content)?.isVisible(WindowInsetsCompat.Type.ime())} focus=${shown.content.findFocus()?.javaClass?.simpleName}")
        snapshot = try { NativeViewState.capture(shown.content, shown.identity, shown.viewport) }
            catch (_: NativeViewState.BudgetExceeded) {
                Log.w("APViewState", "Sheet metadata limit reached; state restoration skipped")
                null
            }
    }
    fun saveState(out: Bundle) {
        main(); capture()
        snapshot?.let { saved ->
            try {
                val bundle = NativeViewState.toBundle(saved)
                if (NativeViewState.encodedSize(bundle) <= NativeViewState.MAX_SAVED_BYTES) out.putBundle(STATE, bundle)
            } catch (_: NativeViewState.BudgetExceeded) { /* Bounded state is optional, not application data. */ }
        }
    }
    fun clearSnapshot() { snapshot = null }
    fun reconcile(nextIdentity: String?): Boolean {
        main(); check(current == null)
        val previous = retiredIdentity
        retiredIdentity = null
        return CrystalBridge.completeSheetTransition(previous != null && previous != nextIdentity)
    }
    fun requestDismiss(anchor: NativeSheetAnchor) {
        main()
        val shown = current ?: return
        if (shown.anchor !== anchor || !shown.lease.active || shown.pending != null) return
        val task = Runnable { event(shown) { completePending() } }
        shown.pending = task
        // Called from Crystal -> JNI -> Java. Never re-enter Crystal on this stack.
        handler.post(task)
    }
    fun completePending() {
        main()
        val shown = current ?: return
        if (shown.pending != null) dismiss(shown)
    }
    fun suspend() {
        main()
        try { capture() } catch (error: Throwable) {
            try { retire(false) } catch (cleanup: Throwable) { error.addSuppressed(cleanup) }
            throw error
        }
        retire(false)
    }
    fun close() { main(); retire(false); snapshot = null; retiredIdentity = null }
    private fun retire(userDismissed: Boolean) {
        val shown = current ?: return
        current = null
        retiredIdentity = if (userDismissed) null else shown.identity
        shown.lease.retire()
        shown.pending?.let(handler::removeCallbacks); shown.pending = null
        shown.draw?.let { if (shown.content.viewTreeObserver.isAlive) shown.content.viewTreeObserver.removeOnPreDrawListener(it) }
        shown.windowFocus?.let { if (shown.content.viewTreeObserver.isAlive) shown.content.viewTreeObserver.removeOnWindowFocusChangeListener(it) }
        shown.behaviorCallback?.let { shown.dialog.behavior.removeBottomSheetCallback(it) }
        shown.dialog.setOnCancelListener(null); shown.dialog.setOnDismissListener(null)
        val keyboard = activity.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        shown.dialog.window?.decorView?.windowToken?.let { keyboard.hideSoftInputFromWindow(it, 0) }
        shown.dialog.dismiss()
        (shown.content.parent as? ViewGroup)?.removeView(shown.content)
        shown.anchor.addView(shown.content)
        // A failed session cannot re-enter Crystal. Its normal root teardown
        // still unregisters every token. Ordinary retirement does so now,
        // before an old detached editor/button can deliver a late event.
        if (CrystalBridge.debugSessionState() == HostSession.State.FOREGROUND)
            CrystalBridge.dispatchWindowStateCallback(shown.descriptor.lifecycle, if (userDismissed) 1 else 0)
    }
    private fun dismiss(shown: Presented) {
        if (current !== shown || !shown.lease.active || CrystalBridge.debugSessionState() != HostSession.State.FOREGROUND) return
        snapshot = null
        retire(true)
        CrystalBridge.requestRender()
    }
    private fun state(value: Int, allowed: List<Int>) = when (SheetPolicy.position(value, allowed)) {
        SheetPolicy.Position.COLLAPSED -> BottomSheetBehavior.STATE_COLLAPSED
        SheetPolicy.Position.HALF -> BottomSheetBehavior.STATE_HALF_EXPANDED
        SheetPolicy.Position.EXPANDED -> BottomSheetBehavior.STATE_EXPANDED
    }
    private fun position(state: Int): SheetPolicy.Position? = when (state) {
        BottomSheetBehavior.STATE_COLLAPSED -> SheetPolicy.Position.COLLAPSED
        BottomSheetBehavior.STATE_HALF_EXPANDED -> SheetPolicy.Position.HALF
        BottomSheetBehavior.STATE_EXPANDED -> SheetPolicy.Position.EXPANDED
        else -> null
    }
    private fun updateGeometry(shown: Presented): Boolean {
        val frame = shown.frame ?: return false
        val parent = frame.parent as? View ?: return false
        if (parent.height <= 0) return false
        val insets = ViewCompat.getRootWindowInsets(frame) ?: shown.insets ?: return false
        val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
        val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
        // Nominal compact heights must still fit a native control. Measure
        // actionable content, not an entire scrolling container or column.
        // This remains window-bounded when the app declares an oversized control.
        val control = shown.nodes.maxOfOrNull { node ->
            val target = NativeCompoundFocus.target(node.view)
            if (target.isShown && target.isEnabled && target.isFocusable &&
                (target.isClickable || target is EditText || target is AbsSeekBar))
                maxOf(node.view.measuredHeight, target.measuredHeight)
            else 0
        } ?: 0
        val minimumViewport = maxOf((48 * shown.content.resources.displayMetrics.density).toInt(), control)
        val handle = (0 until shown.shell.childCount).map { shown.shell.getChildAt(it) }
            .filterIsInstance<BottomSheetDragHandleView>().singleOrNull()
        val availableBody = (parent.height.toLong() - bars.top - maxOf(bars.bottom, ime.bottom)).coerceAtLeast(0).toInt()
        // In a cramped keyboard window, prioritize the complete native control.
        // Keep the handle's actual native size; restore it when space returns.
        // measuredHeight remains available while GONE, preventing oscillation.
        val handleVisible = SheetPolicy.keepsHandle(availableBody, minimumViewport, handle?.measuredHeight ?: 0, ime.bottom > 0)
        val handleVisibility = if (handleVisible) View.VISIBLE else View.GONE
        val chromeChanged = handle != null && handle.visibility != handleVisibility
        if (chromeChanged) handle?.visibility = handleVisibility
        val chrome = if (handleVisible) (handle?.measuredHeight ?: 0).toLong() else 0L
        val body = (minimumViewport.toLong() + chrome).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        val geometry = SheetPolicy.geometry(parent.height, bars.top, bars.bottom, ime.bottom, shown.descriptor.detents, body)
        val previousInset = shown.shell.paddingBottom
        val paddingChanged = shown.shell.paddingLeft != bars.left || shown.shell.paddingRight != bars.right ||
            shown.shell.paddingBottom != geometry.bottomInset
        if (paddingChanged) shown.shell.setPadding(bars.left, 0, bars.right, geometry.bottomInset)
        if (shown.geometry == geometry) return paddingChanged || chromeChanged
        shown.geometry = geometry
        shown.revealFocus = true
        val behavior = shown.dialog.behavior
        behavior.expandedOffset = geometry.expandedTop
        behavior.peekHeight = geometry.peekHeight
        behavior.halfExpandedRatio = geometry.halfRatio
        frame.layoutParams = frame.layoutParams.apply { height = geometry.maximumHeight }
        // Resize the shell in the same traversal as its new IME padding. A
        // compact shell left at its old height can briefly measure its editor
        // viewport at zero and transfer focus away before the next pre-draw.
        val visibleHeight = when (position(behavior.state)) {
            SheetPolicy.Position.COLLAPSED -> geometry.peekHeight
            SheetPolicy.Position.HALF -> parent.height - (parent.height * (1f - geometry.halfRatio)).toInt()
            SheetPolicy.Position.EXPANDED -> geometry.maximumHeight
            null -> (SheetPolicy.viewportHeight(parent.height, frame.top, frame.height).toLong() +
                geometry.bottomInset - previousInset).coerceIn(0, geometry.maximumHeight.toLong()).toInt()
        }
        shown.shell.layoutParams = shown.shell.layoutParams.apply { height = visibleHeight }
        frame.requestLayout()
        return true
    }
    private fun fitViewport(shown: Presented): Boolean {
        val frame = shown.frame ?: return false
        val parent = frame.parent as? View ?: return false
        if (parent.height <= 0 || frame.height <= 0 || frame.isLayoutRequested) return false
        val height = SheetPolicy.viewportHeight(parent.height, frame.top, frame.height)
        if (shown.shell.layoutParams.height == height) return false
        shown.shell.layoutParams = shown.shell.layoutParams.apply { this.height = height }
        return true
    }
    fun present(node: NativeViewState.Node, route: String) {
        main(); check(current == null)
        val anchor = node.view as NativeSheetAnchor
        val descriptor = requireNotNull(anchor.descriptor)
        require(anchor.childCount == 1) { "A native sheet requires exactly one content root" }
        val content = anchor.getChildAt(0)
        val contentNodes = NativeViewState.nodes(content)
        require(contentNodes.none {
            (it.view is NativeSheetAnchor && it.view.descriptor != null) ||
                (it.view is NativeDialogAnchor && it.view.descriptor != null)
        }) { "Nested active modal declarations require explicit presentation sequencing" }
        val identity = SheetPolicy.identity(route, node.identity.address)
        val dialog = SheetWindow(activity, content)
        val shell = LinearLayout(dialog.context).apply {
            orientation = LinearLayout.VERTICAL
            isFocusableInTouchMode = true
            descendantFocusability = ViewGroup.FOCUS_BEFORE_DESCENDANTS
            isSaveEnabled = false; isSaveFromParentEnabled = false
        }
        if (descriptor.drag) shell.addView(BottomSheetDragHandleView(dialog.context), LinearLayout.LayoutParams(-1, -2))
        val viewport = NestedScrollView(dialog.context).apply { isFillViewport = false; isSaveFromParentEnabled = false }
        shell.addView(viewport, LinearLayout.LayoutParams(-1, 0, 1f))
        val shown = Presented(dialog, anchor, content, shell, viewport, descriptor, identity, contentNodes)
        try {
            // Keep the sheet's native controls available in landscape. This is
            // a request to compliant keyboards, not a guarantee about third-
            // party IMEs. Preserve each editor's action and other option bits.
            contentNodes.forEach { child ->
                (NativeCompoundFocus.target(child.view) as? EditText)?.let { editor ->
                    // No fullscreen and no extract UI: a landscape keyboard that
                    // takes over the screen also takes window focus from the sheet.
                    editor.imeOptions = editor.imeOptions or EditorInfo.IME_FLAG_NO_FULLSCREEN or EditorInfo.IME_FLAG_NO_EXTRACT_UI
                }
            }
            anchor.removeView(content)
            viewport.addView(content, ViewGroup.LayoutParams(-1, -2))
            content.isSaveEnabled = false; content.isSaveFromParentEnabled = false
            NativeWindowScope.bind(content, shown.lease)
            dialog.setContentView(shell, ViewGroup.LayoutParams(-1, -1))
            dialog.setTitle(descriptor.title)
            dialog.setCancelable(!descriptor.locked)
            dialog.setCanceledOnTouchOutside(!descriptor.locked)
            dialog.dismissWithAnimation = false
            dialog.window?.let { window ->
                WindowCompat.setDecorFitsSystemWindows(window, false)
                // This window owns IME avoidance through insets. Do not also
                // ask WindowManager to shrink its height by the same amount.
                // A sheet that saved a visible keyboard declares it before the
                // window attaches, so the system shows the keyboard as part of
                // window focus instead of the client racing the input target;
                // Android 16 no longer restores it on its own and rejects the
                // early client request (see restoreKeyboard).
                val restoringKeyboard = snapshot?.takeIf { it.route == identity }?.ime == true
                val state = if (restoringKeyboard) WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
                            else WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN
                android.util.Log.d(DEBUG_TAG, "present restoringKeyboard=$restoringKeyboard")
                window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING or state)
            }
            current = shown
            NativeSemantics.metadata(anchor)?.let { NativeSemantics.decorate(shell, it) }
            ViewCompat.setAccessibilityPaneTitle(shell, descriptor.title)
            ViewCompat.setOnApplyWindowInsetsListener(shell) { _, insets ->
                event(shown) {
                    shown.insets = insets
                    updateGeometry(shown)
                }
                insets
            }
            dialog.show()
            // Track IME animations so a keyboard-restore retry never hides a
            // keyboard whose show is still in flight (that is what a blind
            // hide-then-show did under load on Android 15).
            ViewCompat.setWindowInsetsAnimationCallback(content, object : WindowInsetsAnimationCompat.Callback(WindowInsetsAnimationCompat.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE) {
                override fun onPrepare(animation: WindowInsetsAnimationCompat) {
                    if (animation.typeMask and WindowInsetsCompat.Type.ime() != 0) shown.imeAnimating = true
                }
                override fun onProgress(insets: WindowInsetsCompat, running: MutableList<WindowInsetsAnimationCompat>): WindowInsetsCompat = insets
                override fun onEnd(animation: WindowInsetsAnimationCompat) {
                    if (animation.typeMask and WindowInsetsCompat.Type.ime() != 0) shown.imeAnimating = false
                }
            })
            // Report the keyboard as requested from the window's first insets
            // report. Android 16 syncs IME visibility to the client's requested
            // types, so a window that declared ALWAYS_VISIBLE but reported no
            // IME request gets hidden again (IME_REQUESTED_CHANGED_LISTENER).
            if (snapshot?.takeIf { it.route == identity }?.ime == true) {
                dialog.window?.let { WindowCompat.getInsetsController(it, shell).show(WindowInsetsCompat.Type.ime()) }
            }
            val sheet = requireNotNull(dialog.findViewById<FrameLayout>(com.google.android.material.R.id.design_bottom_sheet))
            shown.frame = sheet
            sheet.layoutParams = sheet.layoutParams.apply { height = ViewGroup.LayoutParams.MATCH_PARENT }
            dialog.behavior.apply {
                // One/two allowed heights use Material's content-fit endpoints,
                // so scrolling cannot drag into an undeclared higher detent.
                isFitToContents = descriptor.detents.size < 3
                halfExpandedRatio = 0.5f
                peekHeight = (activity.resources.displayMetrics.heightPixels * 0.25f).toInt()
                isGestureInsetBottomIgnored = true
                isHideable = !descriptor.locked
                skipCollapsed = false
                isDraggable = descriptor.detents.size > 1 || !descriptor.locked
                state = state(descriptor.selected, descriptor.detents)
            }
            val behaviorCallback = object : BottomSheetBehavior.BottomSheetCallback() {
                override fun onSlide(view: View, offset: Float) { event(shown) { fitViewport(shown) } }
                override fun onStateChanged(view: View, newState: Int) {
                    event(shown) {
                        val position = position(newState) ?: return@event
                        val value = SheetPolicy.value(position, descriptor.detents)
                        if (SheetPolicy.position(value, descriptor.detents) != position) {
                            dialog.behavior.state = state(value, descriptor.detents); return@event
                        }
                        CrystalBridge.dispatchWindowStateCallback(descriptor.changed, value)
                    }
                }
            }
            shown.behaviorCallback = behaviorCallback
            dialog.behavior.addBottomSheetCallback(behaviorCallback)
            dialog.setOnCancelListener { event(shown) { dismiss(shown) } }
            dialog.setOnDismissListener { event(shown) { dismiss(shown) } }
            val listener = object : ViewTreeObserver.OnPreDrawListener {
                override fun onPreDraw(): Boolean {
                    var ready = true
                    event(shown) {
                        val geometryChanged = updateGeometry(shown)
                        val viewportChanged = fitViewport(shown)
                        if (geometryChanged || viewportChanged || shell.isLayoutRequested) {
                            ready = false
                            return@event
                        }
                        if (shown.restored) {
                            if (shown.revealFocus) {
                                shown.revealFocus = false
                                content.findFocus()?.let { it.requestRectangleOnScreen(Rect(0, 0, it.width, it.height), true) }
                            }
                            return@event
                        }
                        val saved = snapshot?.takeIf { it.route == identity }
                        val requested = NativeSemantics.applyFocusRequests(content)
                        val result = saved?.let { NativeViewState.restore(content, identity, it, viewport, requested == null) }
                        requested?.requestRectangleOnScreen(Rect(0, 0, requested.width, requested.height), true)
                        shown.restored = true
                        val editor = (requested as? EditText) ?: result?.second
                        if (editor != null) restoreKeyboard(shown, editor, saved?.ime == true)
                    }
                    return ready
                }
            }
            shown.draw = listener
            content.viewTreeObserver.addOnPreDrawListener(listener)
            ViewCompat.requestApplyInsets(shell)
        } catch (error: Throwable) {
            try {
                if (current === shown) retire(false) else {
                    shown.lease.retire(); dialog.dismiss()
                    (content.parent as? ViewGroup)?.removeView(content); anchor.addView(content)
                }
            } catch (cleanup: Throwable) { error.addSuppressed(cleanup) }
            throw error
        }
    }
    private fun restoreKeyboard(shown: Presented, editor: EditText, visible: Boolean) {
        android.util.Log.d(DEBUG_TAG, "restoreKeyboard visible=$visible attached=${editor.isAttachedToWindow} windowFocus=${shown.content.hasWindowFocus()} imeNow=${ViewCompat.getRootWindowInsets(shown.content)?.isVisible(WindowInsetsCompat.Type.ime())}")
        // The initial hidden policy must not race a saved visible editor when
        // WindowManager finishes focusing a recreated/rotated window.
        // The window already declared ALWAYS_VISIBLE at presentation when the
        // saved state had a keyboard; keep that declaration until focus lands.
        fun apply() {
            event(shown) {
                android.util.Log.d(DEBUG_TAG, "restoreKeyboard.apply visible=$visible attached=${editor.isAttachedToWindow} focused=${editor.isFocused} windowFocus=${shown.content.hasWindowFocus()}")
                if (!editor.isAttachedToWindow) return@event
                val keyboard = activity.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                if (!visible) { keyboard.hideSoftInputFromWindow(editor.windowToken, 0); return@event }
                // Android 15 re-showed a saved-visible keyboard for a recreated
                // window itself (SHOW_RESTORE_IME_VISIBILITY). Android 16 does
                // not, and a plain showSoftInput issued as the new dialog window
                // gains focus fails server-side (PHASE_SERVER_UPDATE_CLIENT_VISIBILITY)
                // because that window is not yet the input target. The insets
                // controller retains the request until the window becomes the
                // target, so ask through it, then confirm once and retry with the
                // direct call if the first request was dropped.
                // The window declared ALWAYS_VISIBLE and requested the IME at
                // presentation, so the system shows it as focus lands. A client
                // request here cancels that in-flight show on Android 16
                // (PHASE_CLIENT_APPLY_ANIMATION), so only confirm afterwards.
                editor.requestFocus()
                fun confirm(attempt: Int) {
                    editor.postDelayed({
                        event(shown) {
                            if (!editor.isAttachedToWindow || !editor.isFocused) return@event
                            val shownNow = ViewCompat.getRootWindowInsets(editor)?.isVisible(WindowInsetsCompat.Type.ime()) == true
                            android.util.Log.d(DEBUG_TAG, "restoreKeyboard.confirm attempt=$attempt imeNow=$shownNow animating=${shown.imeAnimating}")
                            if (shownNow || attempt >= RESTORE_CONFIRM_ATTEMPTS) return@event
                            if (shown.imeAnimating) { confirm(attempt + 1); return@event }
                            // Staged, one action per interval. The system's own show can
                            // still be pending on the first check, and a hide issued
                            // together with a show can land after it (observed on API 35:
                            // HIDE_SOFT_INPUT_ON_ANIMATION_STATE_CHANGED after onShown).
                            // 1: wait. 2: re-request. 3: clear the stuck requested state
                            // with a hide. 4: request again. Then give up.
                            val window = shown.dialog.window
                            when (attempt) {
                                1 -> Unit
                                2, 4 -> if (window != null) WindowCompat.getInsetsController(window, editor).show(WindowInsetsCompat.Type.ime()) else keyboard.showSoftInput(editor, 0)
                                3 -> if (window != null) WindowCompat.getInsetsController(window, editor).hide(WindowInsetsCompat.Type.ime())
                            }
                            confirm(attempt + 1)
                        }
                    }, RESTORE_CONFIRM_DELAY_MS)
                }
                confirm(1)
            }
        }
        if (shown.content.hasWindowFocus()) { shown.content.post { apply() }; return }
        val listener = object : ViewTreeObserver.OnWindowFocusChangeListener {
            override fun onWindowFocusChanged(hasFocus: Boolean) {
                if (!hasFocus) return
                if (shown.content.viewTreeObserver.isAlive) shown.content.viewTreeObserver.removeOnWindowFocusChangeListener(this)
                shown.windowFocus = null
                shown.content.post { apply() }
            }
        }
        shown.windowFocus = listener
        shown.content.viewTreeObserver.addOnWindowFocusChangeListener(listener)
    }
}
