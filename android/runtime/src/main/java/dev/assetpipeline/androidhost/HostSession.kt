package dev.assetpipeline.androidhost

/** Single-surface, process-retained session. Call only on the application thread.
 * Visibility changes may include a background/foreground pair during recreation.
 * Neither detaching a surface nor an Android process kill is a terminal Stop hook.
 */
class HostSession(private val dispatch: (Int) -> Boolean) {
    enum class State { CREATED, FOREGROUND, BACKGROUND, STOPPED, FAILED }
    var state = State.CREATED
        private set
    private var owner: Any? = null
    private var transitioning = false

    internal fun owns(host: Any) = owner === host

    fun attach(host: Any) {
        checkUsable()
        check(owner == null || owner === host) { "Only one Android host surface is supported" }
        owner = host
    }

    fun foreground(host: Any) {
        checkOwner(host)
        if (state == State.FOREGROUND) return
        transition(1, State.FOREGROUND)
    }

    fun background(host: Any) {
        // A contained native failure still needs the ordinary onStop/onDestroy
        // cleanup path. Never re-enter failed Crystal application logic here.
        if (state == State.FAILED) {
            check(!transitioning && owner === host) { "Android host does not own the failed surface" }
            return
        }
        checkOwner(host)
        if (state != State.FOREGROUND) return
        transition(2, State.BACKGROUND)
    }

    fun <T> nativeCall(action: () -> T): T {
        checkUsable()
        check(state == State.FOREGROUND) { "Native UI calls require a foreground Android session" }
        try {
            return action()
        } catch (error: Throwable) {
            state = State.FAILED
            throw error
        }
    }

    fun detach(host: Any, releaseViews: () -> Unit) {
        check(!transitioning) { "Android lifecycle transition is already in progress" }
        check(owner === host) { "Android host does not own the active surface" }
        try {
            if (state == State.FOREGROUND) background(host)
        } finally {
            try { releaseViews() } finally { owner = null }
        }
    }

    // Explicit terminal close only. Android has no reliable process-exit hook.
    fun close() {
        check(!transitioning) { "Android lifecycle transition is already in progress" }
        check(owner == null) { "Detach the Android surface before closing the session" }
        if (state == State.STOPPED || state == State.FAILED) return
        transition(3, State.STOPPED)
    }

    private fun checkUsable() {
        check(!transitioning) { "Android lifecycle transition is already in progress" }
        check(state != State.STOPPED && state != State.FAILED) { "Android session is terminal: $state" }
    }

    private fun checkOwner(host: Any) {
        checkUsable()
        check(owner === host) { "Android host does not own the active surface" }
    }

    private fun transition(event: Int, next: State) {
        checkUsable()
        transitioning = true
        try {
            check(dispatch(event)) { "Crystal lifecycle event $event failed; inspect AssetPipelineNative logs" }
            state = next
        } catch (error: Throwable) {
            state = State.FAILED
            throw error
        } finally { transitioning = false }
    }
}
