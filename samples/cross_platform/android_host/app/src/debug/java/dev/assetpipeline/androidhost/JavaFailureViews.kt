package dev.assetpipeline.androidhost

import android.content.Context
import android.view.View
import android.widget.TextView

// Deliberate constructor/setter failures exist only in the sample debug APK.
class JavaFixtureFailure(message: String) : RuntimeException(message)

class ThrowingConstructorView(context: Context) : View(context) {
    init { throw JavaFixtureFailure("private-java-constructor-message") }
}

class ThrowingTextView(context: Context) : TextView(context) {
    private var armed = false
    init { armed = true }
    override fun setText(text: CharSequence?, type: BufferType?) {
        if (armed) throw JavaFixtureFailure(text?.toString() ?: "private-java-null")
        super.setText(text, type)
    }
}
