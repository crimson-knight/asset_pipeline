package dev.assetpipeline.androidhost

import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException
import org.junit.Assert.*
import org.junit.Test

class ServiceQueueTest {
    @Test fun cancellationHookRunsOnceWhileCompletionWaitsForWorkCleanup() {
        val h = Harness()
        var cancelled = 0
        assertTrue(h.queue.submit(1, { cancelled++ }) { ServiceReply(ServiceStatus.OK) })
        h.queue.cancel(1); h.queue.cancel(1); h.queue.close()
        assertEquals(1, cancelled)
        assertTrue(h.replies.isEmpty())
        h.work(); h.deliver()
        assertEquals(ServiceStatus.CANCELLED, h.replies.single().second.status)
        h.queue.cancel(1)
        assertEquals(1, cancelled)
    }
    private class Harness(limit: Int = 64) {
        val workers = ArrayDeque<Runnable>()
        val deliveries = ArrayDeque<Runnable>()
        val replies = mutableListOf<Pair<Long, ServiceReply>>()
        var host = true
        val queue = ServiceQueue(Executor { workers.add(it) }, { deliveries.add(it) }, { check(host) },
            { id, result -> replies.add(Pair(id, result)) }, limit)
        fun work() { host = false; try { workers.removeFirst().run() } finally { host = true } }
        fun deliver() { deliveries.removeFirst().run() }
    }

    @Test fun resultIsDeferredUntilTheHostQueueRunsAndRemovedBeforeCompletion() {
        val h = Harness()
        assertTrue(h.queue.submit(1) { assertFalse(h.host); ServiceReply(ServiceStatus.OK, byteArrayOf(42)) })
        assertEquals(1, h.queue.pendingCount)
        assertTrue(h.replies.isEmpty())
        h.work()
        assertTrue(h.replies.isEmpty())
        h.deliver()
        assertEquals(0, h.queue.pendingCount)
        assertArrayEquals(byteArrayOf(42), h.replies.single().second.data)
    }
    @Test fun queuedCancellationIsIdempotentAndPreventsWork() {
        val h = Harness()
        h.queue.submit(1) { fail("cancelled queued work ran"); ServiceReply(ServiceStatus.OK) }
        h.queue.cancel(1); h.queue.cancel(1)
        assertTrue(h.replies.isEmpty())
        h.work(); h.deliver()
        h.queue.cancel(1)
        assertEquals(ServiceStatus.CANCELLED, h.replies.single().second.status)
        assertEquals(0, h.queue.pendingCount)
    }
    @Test fun cancellationAfterWorkDoesNotPretendToRollBackEffects() {
        val h = Harness()
        var committed = false
        h.queue.submit(1) { committed = true; ServiceReply(ServiceStatus.OK) }
        h.work(); h.queue.cancel(1); h.deliver()
        assertTrue(committed)
        assertEquals(ServiceStatus.CANCELLED, h.replies.single().second.status)
    }
    @Test fun duplicateDeliveryCompletesExactlyOnce() {
        val h = Harness()
        h.queue.submit(1) { ServiceReply(ServiceStatus.OK) }
        h.work()
        val delivery = h.deliveries.removeFirst()
        delivery.run(); delivery.run()
        assertEquals(1, h.replies.size)
    }
    @Test fun boundedQueueRejectsDuplicateAndOverflowWithoutLeakingEntries() {
        val h = Harness(1)
        assertFalse(h.queue.submit(0) { ServiceReply(ServiceStatus.OK) })
        assertTrue(h.queue.submit(1) { ServiceReply(ServiceStatus.OK) })
        assertFalse(h.queue.submit(1) { ServiceReply(ServiceStatus.OK) })
        assertFalse(h.queue.submit(2) { ServiceReply(ServiceStatus.OK) })
        assertEquals(1, h.queue.pendingCount)
        h.work(); h.deliver()
        assertTrue(h.queue.submit(2) { ServiceReply(ServiceStatus.OK) })
    }
    @Test fun staleDeliveryCannotRemoveANewerOperationWithTheSameIdentifier() {
        val h = Harness()
        h.queue.submit(1) { ServiceReply(ServiceStatus.OK) }
        h.work()
        val old = h.deliveries.removeFirst()
        old.run()
        h.queue.submit(1) { ServiceReply(ServiceStatus.NOT_FOUND) }
        old.run()
        assertEquals(1, h.queue.pendingCount)
        h.work(); h.deliver()
        assertEquals(listOf(ServiceStatus.OK, ServiceStatus.NOT_FOUND), h.replies.map { it.second.status })
    }
    @Test fun closingCancelsAcceptedOperationsButStillDeliversTheirCompletions() {
        val h = Harness()
        h.queue.submit(1) { ServiceReply(ServiceStatus.OK) }
        h.queue.submit(2) { ServiceReply(ServiceStatus.OK) }
        h.work(); h.queue.close(); h.queue.close()
        assertFalse(h.queue.submit(3) { ServiceReply(ServiceStatus.OK) })
        h.work(); h.deliver(); h.deliver()
        assertEquals(listOf(ServiceStatus.CANCELLED, ServiceStatus.CANCELLED), h.replies.map { it.second.status })
        assertEquals(0, h.queue.pendingCount)
    }
    @Test fun executionFailuresBecomeTypedErrorsWithoutLeakingPrivateMessages() {
        val h = Harness()
        val errors = listOf(SecurityException("private"), IllegalArgumentException("private"), java.io.IOException("private"))
        errors.forEachIndexed { i, error -> h.queue.submit(i.toLong() + 1) { throw error } }
        repeat(3) { h.work(); h.deliver() }
        assertEquals(listOf(ServiceStatus.PERMISSION_DENIED, ServiceStatus.INVALID_INPUT, ServiceStatus.IO), h.replies.map { it.second.status })
        assertTrue(h.replies.all { it.second.data.isEmpty() })
    }
    @Test fun rejectedExecutorDoesNotAcceptAnOperation() {
        val queue = ServiceQueue(Executor { throw RejectedExecutionException() }, { fail("posted rejected work") }, {}, { _, _ -> fail("completed rejected work") })
        assertFalse(queue.submit(1) { ServiceReply(ServiceStatus.OK) })
        assertEquals(0, queue.pendingCount)
    }
    @Test fun completionFailureDoesNotRetainOrRetryTheOperation() {
        val tasks = ArrayDeque<Runnable>()
        var completions = 0
        val queue = ServiceQueue(Executor { it.run() }, { tasks.add(it) }, {}, { _, _ -> completions++; throw IllegalStateException("consumer failed") })
        queue.submit(1) { ServiceReply(ServiceStatus.OK) }
        val task = tasks.removeFirst()
        assertThrows(IllegalStateException::class.java) { task.run() }
        assertEquals(0, queue.pendingCount)
        task.run()
        assertEquals(1, completions)
    }
    @Test fun bookkeepingRejectsTheWrongThread() {
        val h = Harness()
        h.host = false
        assertThrows(IllegalStateException::class.java) { h.queue.submit(1) { ServiceReply(ServiceStatus.OK) } }
        assertThrows(IllegalStateException::class.java) { h.queue.cancel(1) }
        assertThrows(IllegalStateException::class.java) { h.queue.close() }
    }
}
