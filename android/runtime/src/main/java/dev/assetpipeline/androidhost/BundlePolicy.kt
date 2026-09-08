package dev.assetpipeline.androidhost

/** Pure rules for bundled files: which asset names may be extracted, which
 * install a copy belongs to, which file paths an application may load, and
 * the density an image file's name declares. */
object BundlePolicy {
    const val ROOT = "ap_bundle"
    const val MAX_NAME_BYTES = 1024

    /** The install a copy belongs to; a new version or a reinstall changes it. */
    fun stamp(versionCode: Long, lastUpdateTime: Long): String = "$versionCode:$lastUpdateTime"

    /** An asset path the extractor will copy: inside the bundle root, with plain segments. */
    fun validName(name: String): Boolean {
        if (name.isBlank() || name.toByteArray(Charsets.UTF_8).size > MAX_NAME_BYTES) return false
        if (name.any { it.code < 32 || it.code == 127 || it == '\\' || it == ' ' }) return false
        if (!name.startsWith("$ROOT/")) return false
        return name.split('/').all { it.isNotEmpty() && it != "." && it != ".." }
    }

    /** A canonical file path an application may load: inside its own private data directory. */
    fun insideStorage(canonicalPath: String, canonicalDataDir: String): Boolean =
        canonicalDataDir.isNotEmpty() && canonicalPath.startsWith("$canonicalDataDir/") &&
            canonicalPath.length > canonicalDataDir.length + 1

    /** The bitmap density an image file's name declares the iOS way: at-2x
     * and at-3x suffixes before the extension; plain names are 1x, one pixel per dp. */
    fun densityFor(fileName: String): Int {
        val stem = fileName.substringBeforeLast('.')
        return when {
            stem.endsWith("@3x") -> 480
            stem.endsWith("@2x") -> 320
            else -> 160
        }
    }
}
