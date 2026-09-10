package dev.assetpipeline.androidhost

import org.junit.Assert.*
import org.junit.Test

class DialogPolicyTest {
    private fun descriptor() = DialogPolicy.Descriptor("Delete 雪?", "A native confirmation.",
        listOf(DialogPolicy.Action("Keep", "cancel", 1), DialogPolicy.Action("Delete", "destructive", 2)), 3)
    @Test fun validatesNativeActionsWithoutDroppingUnsupportedOnes() {
        assertEquals(descriptor(), DialogPolicy.validate(descriptor()))
        for (value in listOf(descriptor().copy(title = " "), descriptor().copy(message = "x".repeat(8193)),
            descriptor().copy(actions = emptyList()), descriptor().copy(actions = List(4) { DialogPolicy.Action("Action", "default", it + 10L) }),
            descriptor().copy(actions = listOf(DialogPolicy.Action("A", "cancel", 1), DialogPolicy.Action("B", "cancel", 2))),
            descriptor().copy(cancel = 1), descriptor().copy(actions = listOf(DialogPolicy.Action("A", "unknown", 1))))) {
            assertThrows(IllegalArgumentException::class.java) { DialogPolicy.validate(value) }
        }
    }
    @Test fun signatureIgnoresReallocatedCallbacksButNotPresentationChanges() {
        val value = descriptor()
        assertEquals(value.signature, value.copy(cancel = 10, actions = value.actions.map { it.copy(token = it.token + 10) }).signature)
        assertNotEquals(value.signature, value.copy(title = "Different").signature)
        assertNotEquals(value.signature, value.copy(actions = value.actions.reversed()).signature)
    }
    @Test fun focusIsBoundedAndScopedToTheSamePresentation() {
        val value = descriptor()
        val focus = DialogPolicy.Focus("screen:confirmation", value.signature, 1)
        assertTrue(focus.matches("screen:confirmation", value))
        assertFalse(focus.matches("other-screen", value))
        assertFalse(focus.matches("screen:confirmation", value.copy(message = "Changed")))
        assertFalse(focus.copy(index = 3).valid())
        assertFalse(focus.copy(identity = "x".repeat(8193)).valid())
    }
    @Test fun retirementAndFirstDismissalRejectLateCallbacks() {
        val lease = DialogPolicy.Lease()
        assertTrue(lease.consume()); assertFalse(lease.consume())
        val retired = DialogPolicy.Lease()
        retired.retire(); assertFalse(retired.consume())
    }
    @Test fun actionAutomationIdsRemainBoundedWithoutChangingOrdinaryIds() {
        assertNull(DialogPolicy.actionTestId(null, 0))
        assertEquals("alert.action.2", DialogPolicy.actionTestId("alert", 2))
        val base = "雪".repeat(341)
        val id = requireNotNull(DialogPolicy.actionTestId(base, 1))
        assertTrue(id.toByteArray(Charsets.UTF_8).size <= 1024)
        assertEquals(id, DialogPolicy.actionTestId(base, 1))
        assertNotEquals(id, DialogPolicy.actionTestId(base, 2))
        assertNotEquals(id, DialogPolicy.actionTestId(base + "a", 1))
    }
}
