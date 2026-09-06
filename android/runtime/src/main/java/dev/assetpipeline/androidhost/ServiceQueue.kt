package dev.assetpipeline.androidhost

import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean

enum class ServiceStatus(val wire: Int) {
    OK(0), NOT_FOUND(1), UNAVAILABLE(2), PERMISSION_DENIED(3), CANCELLED(4), INVALID_INPUT(5), IO(6), NETWORK(7)
}
data class ServiceReply(val status: ServiceStatus, val data: ByteArray = byteArrayOf())

/** All bookkeeping and completions are on the host thread. Workers never enter
 * Crystal. Cancellation waits for work to finish and does not roll back effects.
 */
class ServiceQueue(
    private val worker: Executor,
    private val post: (Runnable) -> Unit,
    private val assertHost: () -> Unit,
    private val complete: (Long, ServiceReply) -> Unit,
    private val limit: Int = 64,
) {
    private class Pending(val onCancel: () -> Unit) { val cancelled = AtomicBoolean(false) }
    private val pending = mutableMapOf<Long, Pending>()
    private var closed = false
    val pendingCount: Int get() { assertHost(); return pending.size }

    fun submit(id: Long, onCancel: () -> Unit = {}, work: () -> ServiceReply): Boolean {
        assertHost()
        if (closed || id <= 0 || pending.containsKey(id) || pending.size >= limit) return false
        val entry = Pending(onCancel)
        val cancelled = entry.cancelled
        pending[id] = entry
        try {
            worker.execute {
                val reply = if (cancelled.get()) ServiceReply(ServiceStatus.CANCELLED) else try {
                    work()
                } catch (_: SecurityException) {
                    ServiceReply(ServiceStatus.PERMISSION_DENIED)
                } catch (_: IllegalArgumentException) {
                    ServiceReply(ServiceStatus.INVALID_INPUT)
                } catch (_: Exception) {
                    ServiceReply(ServiceStatus.IO)
                }
                post(Runnable {
                    assertHost()
                    if (pending[id] === entry) {
                        pending.remove(id)
                        complete(id, if (cancelled.get()) ServiceReply(ServiceStatus.CANCELLED) else reply)
                    }
                })
            }
        } catch (_: RejectedExecutionException) {
            pending.remove(id)
            return false
        }
        return true
    }

    fun cancel(id: Long) {
        assertHost()
        pending[id]?.let { if (it.cancelled.compareAndSet(false, true)) it.onCancel() }
    }
    fun close() { assertHost(); closed = true; pending.keys.toList().forEach(::cancel) }
}
