package dev.assetpipeline.androidhost

/** Host tick scheduling, kept pure so the JVM suite can pin it. Ticks exist
 * only while a foreground session asked for them, and a slow tick (a blocking
 * fetch) shortens the following delay instead of queuing a burst behind it.
 */
object TickPolicy {
    const val MINIMUM_DELAY_MS = 16L

    /** True when the host should schedule ticks: the application registered a
     * positive interval and the surface is in the foreground. */
    fun schedules(intervalMs: Long, state: HostSession.State): Boolean {
        require(intervalMs >= 0) { "Tick interval must not be negative" }
        return intervalMs > 0 && state == HostSession.State.FOREGROUND
    }

    /** Delay until the next tick after one that took `elapsedMs` to run. */
    fun nextDelay(intervalMs: Long, elapsedMs: Long): Long {
        require(intervalMs > 0) { "Tick interval must be positive" }
        require(elapsedMs >= 0) { "Elapsed time must not be negative" }
        return maxOf(intervalMs - elapsedMs, MINIMUM_DELAY_MS)
    }
}
