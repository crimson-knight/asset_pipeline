package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class TickPolicyTest {
    @Test fun ticksExistOnlyForAForegroundSessionThatAskedForThem() {
        assertTrue(TickPolicy.schedules(1000L, HostSession.State.FOREGROUND))
        assertFalse(TickPolicy.schedules(0L, HostSession.State.FOREGROUND))
        for (state in listOf(HostSession.State.CREATED, HostSession.State.BACKGROUND, HostSession.State.STOPPED, HostSession.State.FAILED))
            assertFalse("no ticks in $state", TickPolicy.schedules(1000L, state))
    }
    @Test fun aSlowTickShortensTheNextDelayInsteadOfQueuingABurst() {
        assertEquals(1000L, TickPolicy.nextDelay(1000L, 0L))
        assertEquals(400L, TickPolicy.nextDelay(1000L, 600L))
        assertEquals(TickPolicy.MINIMUM_DELAY_MS, TickPolicy.nextDelay(1000L, 1000L))
        assertEquals(TickPolicy.MINIMUM_DELAY_MS, TickPolicy.nextDelay(1000L, 6000L))
    }
    @Test fun invalidIntervalsAndElapsedTimesAreRejected() {
        assertThrows(IllegalArgumentException::class.java) { TickPolicy.schedules(-1L, HostSession.State.FOREGROUND) }
        assertThrows(IllegalArgumentException::class.java) { TickPolicy.nextDelay(0L, 0L) }
        assertThrows(IllegalArgumentException::class.java) { TickPolicy.nextDelay(1000L, -1L) }
    }
}
