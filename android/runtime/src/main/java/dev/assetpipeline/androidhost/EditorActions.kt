package dev.assetpipeline.androidhost

/** Platform integer protocol, kept free of Android classes for JVM tests. */
internal object EditorActions {
    const val IGNORE = 0
    const val SUBMIT = 1
    const val CONSUME = 2
    fun interpret(actionId: Int, keyCode: Int?, keyAction: Int?, repeatCount: Int): Int {
        // IME_ACTION_GO/SEARCH/SEND/DONE; NEXT/PREVIOUS retain focus traversal.
        if (actionId in listOf(2, 3, 4, 6)) return SUBMIT
        if (actionId != 0 || keyCode != 66) return IGNORE // IME_NULL, KEYCODE_ENTER
        return if (keyAction == 0 && repeatCount == 0) SUBMIT else CONSUME
    }
}
