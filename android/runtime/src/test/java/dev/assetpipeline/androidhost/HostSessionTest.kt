package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class HostSessionTest {
    @Test fun nativeCallFailureIsTerminalButBackgroundAndDetachStillCleanUp() {
        val events = mutableListOf<Int>()
        val session = HostSession { events.add(it); true }
        val host = Any()
        session.attach(host)
        session.foreground(host)
        assertEquals(42, session.nativeCall { 42 })
        assertThrows(IllegalArgumentException::class.java) { session.nativeCall { throw IllegalArgumentException("callback failed") } }
        assertEquals(HostSession.State.FAILED, session.state)
        assertThrows(IllegalStateException::class.java) { session.nativeCall { fail("must not re-enter native application") } }
        assertThrows(IllegalStateException::class.java) { session.background(Any()) }
        session.background(host)
        var released = false
        session.detach(host) { released = true }
        assertTrue(released)
        session.close()
        assertEquals(listOf(1), events)
    }

    @Test fun nativeCallRejectsInactiveSessionsWithoutManufacturingFailures() {
        val session = HostSession { true }
        assertThrows(IllegalStateException::class.java) { session.nativeCall { fail("inactive") } }
        assertEquals(HostSession.State.CREATED, session.state)
        val host = Any()
        session.attach(host)
        session.foreground(host)
        session.background(host)
        assertThrows(IllegalStateException::class.java) { session.nativeCall { fail("background") } }
        assertEquals(HostSession.State.BACKGROUND, session.state)
    }

    @Test fun recreationRetainsSessionAndDuplicateVisibilityIsHarmless() {
        val events = mutableListOf<Int>()
        val session = HostSession { events.add(it); true }
        repeat(3) {
            val host = Any()
            session.attach(host)
            session.attach(host)
            session.foreground(host)
            session.foreground(host)
            session.background(host)
            session.background(host)
            session.detach(host) {}
            assertEquals(HostSession.State.BACKGROUND, session.state)
        }
        session.close()
        session.close()
        assertEquals(listOf(1, 2, 1, 2, 1, 2, 3), events)
        assertThrows(IllegalStateException::class.java) { session.attach(Any()) }
    }

    @Test fun aSecondHostCannotOverwriteTheActiveSurface() {
        val session = HostSession { true }
        val host = Any()
        session.attach(host)
        assertThrows(IllegalStateException::class.java) { session.attach(Any()) }
        assertThrows(IllegalStateException::class.java) { session.foreground(Any()) }
        assertThrows(IllegalStateException::class.java) { session.detach(Any()) { fail("wrong owner released views") } }
        assertThrows(IllegalStateException::class.java) { session.close() }
        session.foreground(host)
        assertEquals(HostSession.State.FOREGROUND, session.state)
    }

    @Test fun unstartedSurfaceDoesNotManufactureBackgroundEvents() {
        val events = mutableListOf<Int>()
        val session = HostSession { events.add(it); true }
        val host = Any()
        session.attach(host)
        session.background(host)
        session.detach(host) {}
        assertTrue(events.isEmpty())
        session.close()
        assertEquals(listOf(3), events)
    }

    @Test fun failedNativeDispatchIsTerminalButStillReleasesViews() {
        val session = HostSession { false }
        val host = Any()
        session.attach(host)
        assertThrows(IllegalStateException::class.java) { session.foreground(host) }
        assertEquals(HostSession.State.FAILED, session.state)
        assertThrows(IllegalStateException::class.java) { session.foreground(host) }
        var released = false
        session.detach(host) { released = true }
        assertTrue(released)
        session.close()
    }

    @Test fun failureDuringBackgroundStillReleasesSurfaceAndOwnership() {
        val session = HostSession { it != 2 }
        val host = Any()
        session.attach(host)
        session.foreground(host)
        var released = false
        assertThrows(IllegalStateException::class.java) { session.detach(host) { released = true } }
        assertTrue(released)
        assertEquals(HostSession.State.FAILED, session.state)
        session.close()
    }

    @Test fun failureDuringViewReleaseDoesNotLeakOwner() {
        val session = HostSession { true }
        val host = Any()
        session.attach(host)
        session.foreground(host)
        assertThrows(IllegalArgumentException::class.java) { session.detach(host) { throw IllegalArgumentException("view release") } }
        session.close()
        assertEquals(HostSession.State.STOPPED, session.state)
    }

    @Test fun reentrantHooksFailRatherThanInterleaveTransitions() {
        lateinit var session: HostSession
        val host = Any()
        session = HostSession { session.foreground(host); true }
        session.attach(host)
        assertThrows(IllegalStateException::class.java) { session.foreground(host) }
        assertEquals(HostSession.State.FAILED, session.state)
        session.detach(host) {}
    }

    @Test fun failedStopIsNotRetried() {
        var attempts = 0
        val session = HostSession { attempts++; false }
        assertThrows(IllegalStateException::class.java) { session.close() }
        session.close()
        assertEquals(1, attempts)
        assertEquals(HostSession.State.FAILED, session.state)
    }
}
