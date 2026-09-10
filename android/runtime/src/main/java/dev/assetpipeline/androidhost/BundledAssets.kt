package dev.assetpipeline.androidhost

import android.content.Context
import android.os.Looper
import java.io.File
import java.io.FileNotFoundException

/** The application's bundled files (art, fonts, documents) as real files.
 * The APK's assets/ap_bundle tree is copied once into the application's
 * private files directory, stamped with the installed package version, so an
 * application that resolves art by path, the way it does on iOS, finds the
 * same tree on Android. Later launches of the same install skip the copy. */
object BundledAssets {
    private const val TARGET = "asset_pipeline_bundle"
    @Volatile private var directory: File? = null
    @Volatile private var storageRoot: String? = null
    @Volatile private var extractions = 0

    /** Extracts the bundle, or confirms the copy of this install. Main looper, before the first render. */
    @JvmStatic fun initialize(context: Context) {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Bundled assets initialize on the main looper" }
        val app = context.applicationContext
        storageRoot = File(app.applicationInfo.dataDir).canonicalPath
        val entries = list(app, BundlePolicy.ROOT)
        if (entries.isEmpty()) { directory = null; return }
        val info = app.packageManager.getPackageInfo(app.packageName, 0)
        val stamp = BundlePolicy.stamp(info.longVersionCode, info.lastUpdateTime)
        val target = File(app.filesDir, TARGET)
        val root = File(target, BundlePolicy.ROOT)
        val stampFile = File(target, ".stamp")
        if (root.isDirectory && stampFile.isFile && stampFile.readText() == stamp) { directory = root; return }
        val staging = File(app.filesDir, "$TARGET.tmp")
        staging.deleteRecursively()
        for (entry in entries) {
            check(BundlePolicy.validName(entry)) { "Bundled asset name rejected" }
            val out = File(staging, entry)
            checkNotNull(out.parentFile).mkdirs()
            app.assets.open(entry).use { input -> out.outputStream().use { output -> input.copyTo(output) } }
        }
        File(staging, ".stamp").writeText(stamp)
        target.deleteRecursively()
        check(staging.renameTo(target)) { "Bundled assets could not be committed" }
        extractions++
        directory = root
    }

    /** Every file under the path, as asset names. A directory lists children; a file opens. */
    private fun list(app: Context, path: String): List<String> {
        val children = app.assets.list(path) ?: return emptyList()
        if (children.isNotEmpty()) return children.flatMap { list(app, "$path/$it") }
        return try { app.assets.open(path).close(); listOf(path) } catch (_: FileNotFoundException) { emptyList() }
    }

    /** The extracted bundle's absolute path as UTF-8, or null when this APK carries no bundle. */
    @JvmStatic fun directoryBytes(): ByteArray? = directory?.absolutePath?.toByteArray(Charsets.UTF_8)

    /** The canonical private data directory files may be loaded from; null before initialize. */
    internal fun storageRoot(): String? = storageRoot

    fun debugDirectory(): File? = directory
    fun debugExtractions(): Int = extractions
}
