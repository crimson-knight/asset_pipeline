package dev.assetpipeline.androidhost

/** Host-thread only, bounded, deferred, exactly-once permission completions.
 * One OS dialog may serve several callers. Cancelling a caller does not dismiss
 * that dialog or undo an app-wide grant. Flight IDs reject abandoned results. */
class PermissionRequests(
    private val post: (Runnable) -> Unit,
    private val assertHost: () -> Unit,
    private val launch: (Long) -> ServiceReply?,
    private val complete: (Long, ServiceReply) -> Unit,
    private val limit: Int = 64,
) {
    private class Pending { var flight: Long? = null; var scheduled = false; var cancelled = false }
    private val pending = mutableMapOf<Long, Pending>()
    private var nextFlight = 0L
    private var closed = false
    var activeFlight: Long? = null
        private set
    val pendingCount: Int get() { assertHost(); return pending.size }

    fun submit(id: Long): Boolean {
        assertHost()
        if (closed || id <= 0 || id in pending || pending.size >= limit) return false
        val entry = Pending()
        pending[id] = entry
        post(Runnable {
            assertHost()
            if (pending[id] !== entry || entry.scheduled) return@Runnable
            if (entry.cancelled) { finish(id, entry, ServiceReply(ServiceStatus.CANCELLED)); return@Runnable }
            val existing = activeFlight
            if (existing != null) { entry.flight = existing; return@Runnable }
            if (nextFlight == Long.MAX_VALUE) { finish(id, entry, ServiceReply(ServiceStatus.UNAVAILABLE)); return@Runnable }
            val flight = ++nextFlight
            activeFlight = flight
            entry.flight = flight
            val immediate = try { launch(flight) }
            catch (_: SecurityException) { ServiceReply(ServiceStatus.PERMISSION_DENIED) }
            catch (_: Exception) { ServiceReply(ServiceStatus.UNAVAILABLE) }
            if (immediate != null) result(flight, immediate)
        })
        return true
    }

    fun result(flight: Long, reply: ServiceReply) {
        assertHost()
        if (activeFlight != flight) return
        activeFlight = null
        pending.toMap().forEach { (id, entry) -> if (entry.flight == flight) finish(id, entry, reply) }
    }

    private fun finish(id: Long, entry: Pending, reply: ServiceReply) {
        if (entry.scheduled) return
        entry.scheduled = true
        post(Runnable {
            assertHost()
            if (pending[id] === entry) {
                pending.remove(id)
                complete(id, if (entry.cancelled) ServiceReply(ServiceStatus.CANCELLED) else reply)
            }
        })
    }

    fun cancel(id: Long) {
        assertHost()
        pending[id]?.let { it.cancelled = true; finish(id, it, ServiceReply(ServiceStatus.CANCELLED)) }
    }

    /** Finishing a host abandons its flight. Configuration changes don't call
     * this: the replacement Activity registers the same result key. */
    fun abandon() {
        assertHost()
        activeFlight = null
        pending.toMap().forEach { (id, entry) -> finish(id, entry, ServiceReply(ServiceStatus.UNAVAILABLE)) }
    }
    fun close() {
        assertHost()
        closed = true
        activeFlight = null
        pending.keys.toList().forEach(::cancel)
    }
}
