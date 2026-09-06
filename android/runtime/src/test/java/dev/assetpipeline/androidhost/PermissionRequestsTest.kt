package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class PermissionRequestsTest {
    private class Harness(limit: Int = 64) {
        val tasks = ArrayDeque<Runnable>()
        val flights = mutableListOf<Long>()
        val replies = mutableListOf<Pair<Long, ServiceReply>>()
        var host = true
        var launchResult: ServiceReply? = null
        var launchError: Exception? = null
        val queue = PermissionRequests({ tasks.add(it) }, { check(host) }, {
            flights += it; launchError?.let { error -> throw error }; launchResult
        }, { id, reply -> assertTrue(host); replies += id to reply }, limit)
        fun step() { tasks.removeFirst().run() }
        fun drain() { while (tasks.isNotEmpty()) step() }
        fun result(granted: Boolean = true) { queue.result(flights.last(), ServiceReply(ServiceStatus.OK, byteArrayOf(if (granted) 1 else 0))) }
    }

    @Test fun immediateResultStillCompletesDeferredAndReleasesBeforeCallback() {
        val h = Harness(); h.launchResult = ServiceReply(ServiceStatus.OK, byteArrayOf(1))
        assertTrue(h.queue.submit(1)); assertTrue(h.replies.isEmpty()); h.step()
        assertTrue(h.replies.isEmpty()); assertEquals(1, h.queue.pendingCount); h.step()
        assertEquals(0, h.queue.pendingCount); assertArrayEquals(byteArrayOf(1), h.replies.single().second.data)
    }
    @Test fun callersCoalesceOneDialogAndAResultIsDeliveredOnlyOnce() {
        val h = Harness(); (1L..64L).forEach { assertTrue(h.queue.submit(it)) }; h.drain()
        assertEquals(1, h.flights.size); h.result(false); h.result(true); h.drain()
        assertEquals(64, h.replies.size); assertTrue(h.replies.all { it.second.data.contentEquals(byteArrayOf(0)) })
        assertEquals(0, h.queue.pendingCount)
    }
    @Test fun cancellationBeforeDispatchNeverPromptsAndIsIdempotent() {
        val h = Harness(); h.queue.submit(1); h.queue.cancel(1); h.queue.cancel(1); h.drain()
        assertTrue(h.flights.isEmpty()); assertEquals(ServiceStatus.CANCELLED, h.replies.single().second.status)
    }
    @Test fun cancellationWhileDialogIsOpenReleasesCallerButDoesNotDismissOrRelaunchIt() {
        val h = Harness(); h.queue.submit(1); h.drain(); h.queue.cancel(1); h.drain()
        assertEquals(0, h.queue.pendingCount); assertNotNull(h.queue.activeFlight)
        h.queue.submit(2); h.drain(); assertEquals(1, h.flights.size); h.result(); h.drain()
        assertEquals(listOf(ServiceStatus.CANCELLED, ServiceStatus.OK), h.replies.map { it.second.status })
        assertNull(h.queue.activeFlight)
    }
    @Test fun cancellationAfterResultBeforeDeliveryWinsWithoutUndoingGrant() {
        val h = Harness(); h.queue.submit(1); h.drain(); h.result(); h.queue.cancel(1); h.drain()
        assertEquals(ServiceStatus.CANCELLED, h.replies.single().second.status)
    }
    @Test fun abandonedFlightCannotCompleteANewerHostRequest() {
        val h = Harness(); h.queue.submit(1); h.drain(); val old = h.flights.single()
        h.queue.abandon(); h.drain(); h.queue.submit(2); h.drain()
        h.queue.result(old, ServiceReply(ServiceStatus.OK, byteArrayOf(1))); h.drain()
        assertEquals(1, h.queue.pendingCount); h.result(false); h.drain()
        assertEquals(ServiceStatus.UNAVAILABLE, h.replies.first().second.status)
        assertArrayEquals(byteArrayOf(0), h.replies.last().second.data)
    }
    @Test fun closeCancelsQueuedAndInFlightAndRejectsNewOperations() {
        val h = Harness(); h.queue.submit(1); h.step(); h.queue.submit(2)
        h.queue.close(); h.queue.close(); assertFalse(h.queue.submit(3)); h.result(); h.drain()
        assertEquals(2, h.replies.size); assertTrue(h.replies.all { it.second.status == ServiceStatus.CANCELLED })
        assertEquals(0, h.queue.pendingCount); assertNull(h.queue.activeFlight)
    }
    @Test fun boundedAndDuplicateRejectionsDoNotHaveCallbacks() {
        val h = Harness(1); assertFalse(h.queue.submit(0)); assertFalse(h.queue.submit(-1))
        assertTrue(h.queue.submit(1)); assertFalse(h.queue.submit(1)); assertFalse(h.queue.submit(2))
        h.queue.cancel(1); h.drain(); assertEquals(1, h.replies.size); assertTrue(h.queue.submit(2))
    }
    @Test fun duplicateQueuedDeliveryCannotRemoveAReusedRequestId() {
        val h = Harness(); h.queue.submit(1); h.step(); h.result()
        val old = h.tasks.removeFirst(); old.run(); h.queue.submit(1); old.run()
        assertEquals(1, h.queue.pendingCount); h.drain(); h.result(false); h.drain()
        assertEquals(2, h.replies.size)
    }
    @Test fun launchFailuresBecomeTypedPrivateErrors() {
        val h = Harness(); h.launchError = SecurityException("private")
        h.queue.submit(1); h.drain(); h.launchError = IllegalStateException("private")
        h.queue.submit(2); h.drain()
        assertEquals(listOf(ServiceStatus.PERMISSION_DENIED, ServiceStatus.UNAVAILABLE), h.replies.map { it.second.status })
        assertTrue(h.replies.all { it.second.data.isEmpty() }); assertNull(h.queue.activeFlight)
    }
    @Test fun everyBookkeepingEntryRequiresHostThread() {
        val h = Harness(); h.host = false
        assertThrows(IllegalStateException::class.java) { h.queue.submit(1) }
        assertThrows(IllegalStateException::class.java) { h.queue.cancel(1) }
        assertThrows(IllegalStateException::class.java) { h.queue.result(1, ServiceReply(ServiceStatus.OK)) }
        assertThrows(IllegalStateException::class.java) { h.queue.abandon() }
        assertThrows(IllegalStateException::class.java) { h.queue.close() }
        assertThrows(IllegalStateException::class.java) { h.queue.pendingCount }
    }
}
