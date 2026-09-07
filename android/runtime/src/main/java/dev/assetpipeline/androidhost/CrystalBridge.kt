package dev.assetpipeline.androidhost

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.View

object CrystalBridge {
    data class NativeDebugCounts(
        val globalReferences: Int,
        val callbacks: Int,
    )

    private var didLoad = false
    private var loadedLibrary: String? = null
    var callbackObserver: (() -> Unit)? = null
        set(value) { checkMainThread(); field = value }
    internal var navigationObserver: (() -> Unit)? = null
        set(value) { checkMainThread(); field = value }

    enum class RefreshCause { ACTION, STATE }
    var refreshCause = RefreshCause.ACTION
        private set
    private fun notifyCallback(cause: RefreshCause = RefreshCause.ACTION) {
        val previous = refreshCause
        refreshCause = cause
        try {
            navigationObserver?.invoke()
            callbackObserver?.invoke()
        } finally { refreshCause = previous }
    }
    private val session = HostSession { lifecycleNative(it) }
private var dialogs: NativeDialogHost? = null

// Host tick. One main-looper runnable per foreground session: the first
// tick runs right after the first render, later ticks follow TickPolicy,
// ticks never overlap, and background, detach, close and any boundary
// failure stop them. A tick only runs Crystal work; a re-render happens
// when that work calls requestRender, never on the tick itself.
private val tickHandler = Handler(Looper.getMainLooper())
private var tickIntervalMs = 0L
private var tickRunning = false
private var tickCount = 0L
private val tickRunnable = Runnable { runTick() }

@JvmStatic private external fun tickIntervalNative(): Int
@JvmStatic private external fun tickNative(): Boolean

private fun startTicks() {
    stopTicks()
    tickIntervalMs = nativeCall { tickIntervalNative().toLong() }
    if (TickPolicy.schedules(tickIntervalMs, session.state)) tickHandler.post(tickRunnable)
}

private fun stopTicks() { tickHandler.removeCallbacks(tickRunnable) }

private fun runTick() {
    if (tickRunning || !didLoad || session.state != HostSession.State.FOREGROUND) return
    tickRunning = true
    val started = SystemClock.uptimeMillis()
    try {
        checkedCallback("tick") { tickNative() }
        tickCount++
    } finally { tickRunning = false }
    if (TickPolicy.schedules(tickIntervalMs, session.state)) {
        tickHandler.postDelayed(tickRunnable, TickPolicy.nextDelay(tickIntervalMs, SystemClock.uptimeMillis() - started))
    }
}

/** Ticks dispatched to Crystal since the library loaded. */
fun debugTickCount(): Long { checkMainThread(); return tickCount }

    internal fun installDialogs(owner: Any, host: NativeDialogHost) {
        checkReady()
        check(session.owns(owner) && dialogs == null) { "Dialog host must own the single attached Android surface" }
        dialogs = host
    }
    internal fun removeDialogs(host: NativeDialogHost) {
        checkMainThread()
        if (dialogs === host) dialogs = null
    }
    fun debugDialogCount(): Int { checkMainThread(); return dialogs?.activeCount ?: 0 }
    internal fun requestSheetDismiss(anchor: NativeSheetAnchor) {
        checkReady()
        if (session.state == HostSession.State.FOREGROUND) dialogs?.requestSheetDismiss(anchor)
    }
    @JvmStatic private external fun completeSheetTransitionNative(dismissed: Boolean): Int
    internal fun completeSheetTransition(dismissed: Boolean): Boolean {
        checkReady()
        val result = nativeCall {
            completeSheetTransitionNative(dismissed).also { check(it >= 0) { "Crystal sheet transition failed" } }
        }
        if (result == 1) requestRender()
        return result == 1
    }
    // Native state already reflects detent/retirement. Do not rebuild a window
    // during these callbacks; real dismissal requests its own deferred refresh.
    internal fun dispatchWindowStateCallback(callbackId: Long, value: Int) {
        checkedCallback("int") { dispatchIntCallbackNative(callbackId, value) }
    }
    internal fun synchronizeDialogs(host: NativeDialogHost, root: View, route: String) {
        checkReady(); check(dialogs === host) { "Dialog presentation does not own this surface" }
        nativeCall { host.synchronize(root, route) }
    }

    // Layout/focus/window callbacks run after the originating JNI call returns.
    // They must have the same terminal failure containment as native rendering.
    internal fun windowMutation(action: () -> Unit) {
        checkReady()
        if (session.state != HostSession.State.FOREGROUND) return
        nativeCall(action)
    }

    private fun <T> nativeCall(action: () -> T): T = try { session.nativeCall(action) } catch (error: Throwable) {
        try { dialogs?.suspend() } catch (cleanup: Throwable) { error.addSuppressed(cleanup) }
        throw error
    }

    private fun checkMainThread() {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Crystal Android calls must run on the main looper" }
    }

    private fun checkReady() {
        checkMainThread()
        check(didLoad) { "Crystal native library has not been initialized" }
    }

    private fun checkedCallback(kind: String, call: () -> Boolean) {
        checkReady()
        nativeCall {
            check(call()) { "Crystal $kind callback failed; inspect AssetPipelineNative diagnostics" }
        }
    }

    @Synchronized
    fun initialize(libraryName: String = "android_material_host", context: Context? = null) {
        checkMainThread()
        if (didLoad) {
            check(loadedLibrary == libraryName) { "Crystal runtime already loaded from $loadedLibrary" }
            if (context != null) CrystalServices.initialize(context)
            return
        }
        System.loadLibrary(libraryName)
        loadedLibrary = libraryName
        didLoad = true
        if (context != null) CrystalServices.initialize(context)
    }

    @JvmStatic
    fun dispatchVoidCallback(callbackId: Long) {
        checkedCallback("void") { dispatchVoidCallbackNative(callbackId) }
        notifyCallback()
    }

    @JvmStatic
    fun dispatchStringCallback(callbackId: Long, value: String) {
        checkedCallback("string") { dispatchStringCallbackNative(callbackId, value) }
        navigationObserver?.invoke()
        // The EditText already reflects the keystroke. Rebuilding the entire
        // renderer tree here would replace the focused editor mid-input. A
        // later non-text action can request the sample's full-tree refresh.
    }

    /**
     * A discrete string-valued control (a date or time picker) reports a whole
     * value, not a keystroke, so it refreshes the tree the way a checkbox does.
     */
    @JvmStatic
    fun dispatchDiscreteStringCallback(callbackId: Long, value: String) {
        checkedCallback("string") { dispatchStringCallbackNative(callbackId, value) }
        notifyCallback()
    }

    @JvmStatic
    fun dispatchBoolCallback(callbackId: Long, value: Boolean) {
        checkedCallback("bool") { dispatchBoolCallbackNative(callbackId, value) }
        notifyCallback()
    }

    @JvmStatic
    fun dispatchFloatCallback(callbackId: Long, value: Double) {
        checkedCallback("float") { dispatchFloatCallbackNative(callbackId, value) }
        notifyCallback()
    }

    @JvmStatic
    fun dispatchIntCallback(callbackId: Long, value: Int) {
        checkedCallback("int") { dispatchIntCallbackNative(callbackId, value) }
        notifyCallback()
    }

    @JvmStatic
    private external fun dispatchVoidCallbackNative(callbackId: Long): Boolean

    @JvmStatic
    private external fun dispatchStringCallbackNative(callbackId: Long, value: String): Boolean

    @JvmStatic
    private external fun dispatchBoolCallbackNative(callbackId: Long, value: Boolean): Boolean

    @JvmStatic
    private external fun dispatchFloatCallbackNative(callbackId: Long, value: Double): Boolean

    @JvmStatic
    private external fun dispatchIntCallbackNative(callbackId: Long, value: Int): Boolean

    @JvmStatic
    private external fun teardownNative()

    @JvmStatic
    private external fun lifecycleNative(event: Int): Boolean

    @JvmStatic
    private external fun navigationBackNative(commit: Boolean): Int

    fun canNavigateBack(): Boolean {
        checkReady()
        if (session.state != HostSession.State.FOREGROUND) return false
        val result = nativeCall {
            navigationBackNative(false).also { check(it >= 0) { "Crystal navigation query failed" } }
        }
        return result == 1
    }

    fun navigateBack(): Boolean {
        checkReady()
        if (session.state != HostSession.State.FOREGROUND) return false
        val result = nativeCall {
            navigationBackNative(true).also { check(it >= 0) { "Crystal navigation failed" } }
        }
        if (result == 1) notifyCallback()
        return result == 1
    }

    @JvmStatic
    private external fun debugLiveGlobalRefCountNative(): Int

    @JvmStatic
    private external fun debugCallbackCountNative(): Int

    @JvmStatic
    private external fun servicePendingCountNative(): Int

    @JvmStatic
    external fun debugInitializeAgainNative(): Int

    private external fun renderStudyNative(context: Context, slug: String): View?

    fun renderStudy(context: Context, slug: String): View? {
        checkReady()
        return nativeCall {
            // The low-level public render entrypoint also replaces the owned
            // Crystal root. Retire its old window even when a caller bypasses
            // NativeScreenHost's normal capture/mount sequence.
            dialogs?.beforeRender()
            checkNotNull(renderStudyNative(context, slug)) { "Crystal render failed; inspect AssetPipelineNative diagnostics" }
        }
    }

    fun attachHost(owner: Any) { checkReady(); session.attach(owner); CrystalServices.attachHost(owner) }
    fun foregroundHost(owner: Any) { checkReady(); session.foreground(owner); startTicks() }
    fun backgroundHost(owner: Any) {
        checkReady()
        stopTicks()
        if (session.owns(owner) && session.state == HostSession.State.FOREGROUND) dialogs?.beforeBackground()
        try { session.background(owner) } finally { if (session.owns(owner)) dialogs?.suspend() }
    }

    fun detachHost(owner: Any) {
        checkReady()
        stopTicks()
        session.detach(owner) {
            dialogs?.close()
            dialogs = null
            CrystalServices.detachHost(owner)
            callbackObserver = null
            navigationObserver = null
            teardownNative()
        }
    }

    fun closeSession() {
        checkReady()
        stopTicks()
        try { session.close() } finally {
            if (session.state == HostSession.State.STOPPED || session.state == HostSession.State.FAILED) {
                try { dialogs?.suspend() } finally { CrystalServices.close() }
            }
        }
    }
    @JvmStatic fun requestRender() {
        checkReady()
        if (session.state == HostSession.State.FOREGROUND) notifyCallback(RefreshCause.STATE)
    }
    fun debugPendingServices(): Pair<Int, Int> {
        checkReady()
        return Pair(servicePendingCountNative(), CrystalServices.pendingCount())
    }
    fun debugSessionState(): HostSession.State { checkReady(); return session.state }

    fun teardown() {
        checkMainThread()
        stopTicks()
        dialogs?.suspend()
        if (didLoad) teardownNative()
    }

    fun debugCounts(): NativeDebugCounts {
        checkReady()
        return NativeDebugCounts(
            globalReferences = debugLiveGlobalRefCountNative(),
            callbacks = debugCallbackCountNative(),
        )
    }
}
