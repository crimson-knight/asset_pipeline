package dev.assetpipeline.androidhost
import org.junit.Assert.assertEquals
import org.junit.Test

class EditorActionsTest {
    @Test fun explicitSubmitActionsFire() {
        for (action in listOf(2, 3, 4, 6)) assertEquals(EditorActions.SUBMIT, EditorActions.interpret(action, null, null, 0))
    }
    @Test fun nextPreviousAndUnknownActionsKeepNativeBehavior() {
        for (action in listOf(0, 1, 5, 7, 999)) assertEquals(EditorActions.IGNORE, EditorActions.interpret(action, null, null, 0))
    }
    @Test fun hardwareEnterSubmitsOnlyOnceAndConsumesItsRepeatAndRelease() {
        assertEquals(EditorActions.SUBMIT, EditorActions.interpret(0, 66, 0, 0))
        assertEquals(EditorActions.CONSUME, EditorActions.interpret(0, 66, 0, 1))
        assertEquals(EditorActions.CONSUME, EditorActions.interpret(0, 66, 1, 0))
    }
    @Test fun otherKeysAndTraversalActionsAreNotIntercepted() {
        assertEquals(EditorActions.IGNORE, EditorActions.interpret(0, 67, 0, 0))
        assertEquals(EditorActions.IGNORE, EditorActions.interpret(5, 66, 0, 0))
    }
}
