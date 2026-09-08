package dev.assetpipeline.androidhost

import android.graphics.Typeface
import android.os.Looper
import android.widget.TextView
import java.io.File
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction

/** Typefaces by family name. An application registers the TTF files it
 * bundles under the names its views use (PostScript names on iOS); a view's
 * font resolves to a registered face, else to the Android family of that
 * name (serif, sans-serif-light, monospace), else to the platform default,
 * which is what an unknown name gets on iOS too. */
object FontAssets {
    private val registered = HashMap<String, Typeface>()

    private fun decode(bytes: ByteArray): String? = try {
        Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString()
    } catch (_: Exception) { null }

    /** Registers a TTF or OTF file inside the application's private storage under a family name. */
    @JvmStatic fun register(family: ByteArray, path: ByteArray): Boolean {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Font registration requires the main looper" }
        val name = decode(family)?.takeIf { FontPolicy.validFamily(it) } ?: return false
        val root = BundledAssets.storageRoot() ?: return false
        val file = decode(path)?.let { File(it) } ?: return false
        return try {
            val canonical = file.canonicalPath
            if (!file.isFile || !BundlePolicy.insideStorage(canonical, root)) return false
            registered[name] = Typeface.createFromFile(canonical)
            true
        } catch (_: Exception) { false }
    }

    /** Applies the family's face at the style: registered, generic, or the default. */
    @JvmStatic fun apply(view: TextView, family: ByteArray, style: Int): Boolean {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Typefaces apply on the main looper" }
        val name = decode(family) ?: return false
        if (!FontPolicy.validFamily(name) && !FontPolicy.system(name)) return false
        val face = registered[name]
        view.typeface = when {
            face != null -> Typeface.create(face, FontPolicy.registeredStyle(style))
            FontPolicy.system(name) -> Typeface.defaultFromStyle(style)
            else -> Typeface.create(name, style)
        }
        return true
    }

    fun debugTypeface(family: String): Typeface? = registered[family]
    fun debugRegisteredCount(): Int = registered.size
}
