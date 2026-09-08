package dev.assetpipeline.androidhost

import android.content.Context
import java.io.File

/** The application's private directories as the runtime hands them to
 * Crystal: the files directory (durable, backed up unless the manifest says
 * otherwise) and the cache directory (purgeable by the system). Canonical
 * paths, so what Crystal writes is what the host will read back. */
object AppDirectories {
    const val FILES = 1
    const val CACHE = 2
    @Volatile private var files: String? = null
    @Volatile private var cache: String? = null

    @JvmStatic fun initialize(context: Context) {
        val app = context.applicationContext
        files = File(app.filesDir.absolutePath).canonicalPath
        cache = File(app.cacheDir.absolutePath).canonicalPath
    }

    /** The directory of a kind as UTF-8, or null before initialize or for an unknown kind. */
    @JvmStatic fun pathBytes(kind: Int): ByteArray? = when (kind) {
        FILES -> files
        CACHE -> cache
        else -> null
    }?.toByteArray(Charsets.UTF_8)
}
