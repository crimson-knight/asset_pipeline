package dev.assetpipeline.androidhost

import android.content.res.Resources
import android.graphics.BitmapFactory
import android.os.Looper
import android.util.TypedValue
import android.widget.ImageView
import java.io.File
import androidx.core.content.res.ResourcesCompat
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.WeakHashMap
import org.xmlpull.v1.XmlPullParser

/** Bundled local images only; never an arbitrary path, URI or network loader.
 * Cache resource IDs, not Activity/Drawable/Bitmap instances. Drawables resolve
 * against the current configuration/theme and get independent mutable state. */
object ImageAssets {
    private val catalogs = WeakHashMap<Resources, Map<String, Int>>()
    private const val MAX_PIXELS = 1_048_576L
    @JvmStatic fun setSource(view: ImageView, bytes: ByteArray): Boolean {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Image binding requires the main looper" }
        return try {
            require(bytes.size in 1..1024)
            val name = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString()
            require(name.isNotBlank() && name.none { it.code < 32 || it.code == 127 })
            val resources = view.resources
            val catalog = catalogs.getOrPut(resources) { readCatalog(resources, view.context.packageName) }
            var id = catalog[name] ?: 0
            // Backward-compatible app-local drawable names; never resolve a
            // caller-supplied package/type or a file/network URL.
            if (id == 0 && name.matches(Regex("[a-z][a-z0-9_]*"))) {
                id = resources.getIdentifier(name, "drawable", view.context.packageName)
            }
            if (id == 0) return false
            val value = TypedValue()
            resources.getValue(id, value, true)
            if (value.string?.toString()?.endsWith(".xml") != true) {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true; inScaled = false }
                BitmapFactory.decodeResource(resources, id, bounds)
                require(bounds.outWidth in 1..4096 && bounds.outHeight in 1..4096 && bounds.outWidth.toLong() * bounds.outHeight <= MAX_PIXELS)
                // Account for density scaling before allocating the Drawable.
                val sourceDensity = if (value.density == TypedValue.DENSITY_DEFAULT) 160 else value.density
                val scale = if (sourceDensity == TypedValue.DENSITY_NONE) 1.0 else resources.displayMetrics.densityDpi.toDouble() / sourceDensity
                require(bounds.outWidth * scale <= 4096 && bounds.outHeight * scale <= 4096 && bounds.outWidth * scale * bounds.outHeight * scale <= MAX_PIXELS)
            }
            val drawable = ResourcesCompat.getDrawable(resources, id, view.context.theme) ?: return false
            view.setImageDrawable(drawable.mutate())
            true
        } catch (_: Exception) {
            false
        }
    }

    /** A file inside the application's private storage (the extracted bundle,
     * the files directory, the cache), at the density its name declares the
     * iOS way. Anything outside private storage, or beyond the catalog's
     * decode limits, is refused. */
    @JvmStatic fun setFile(view: ImageView, bytes: ByteArray): Boolean {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Image binding requires the main looper" }
        return try {
            require(bytes.size in 1..4096)
            val path = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString()
            val root = BundledAssets.storageRoot() ?: return false
            val file = File(path)
            val canonical = file.canonicalPath
            if (!file.isFile || !BundlePolicy.insideStorage(canonical, root)) return false
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true; inScaled = false }
            BitmapFactory.decodeFile(canonical, bounds)
            require(bounds.outWidth in 1..4096 && bounds.outHeight in 1..4096 && bounds.outWidth.toLong() * bounds.outHeight <= MAX_PIXELS)
            val bitmap = BitmapFactory.decodeFile(canonical, BitmapFactory.Options().apply { inScaled = false }) ?: return false
            bitmap.density = BundlePolicy.densityFor(file.name)
            view.setImageBitmap(bitmap)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** An encoded image from memory, a photo the application fetched itself,
     * at its own pixels (one per pixel) within the catalog's decode limits. */
    @JvmStatic fun setBytes(view: ImageView, bytes: ByteArray): Boolean {
        check(Looper.myLooper() == Looper.getMainLooper()) { "Image binding requires the main looper" }
        return try {
            require(bytes.size in 1..16_777_216)
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true; inScaled = false }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            require(bounds.outWidth in 1..4096 && bounds.outHeight in 1..4096 && bounds.outWidth.toLong() * bounds.outHeight <= MAX_PIXELS)
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inScaled = false }) ?: return false
            bitmap.density = view.resources.displayMetrics.densityDpi
            view.setImageBitmap(bitmap)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun readCatalog(resources: Resources, packageName: String): Map<String, Int> {
        val resource = resources.getIdentifier("ap_image_catalog", "xml", packageName)
        if (resource == 0) return emptyMap()
        val images = linkedMapOf<String, Int>()
        resources.getXml(resource).use { xml ->
            while (xml.eventType != XmlPullParser.START_TAG && xml.eventType != XmlPullParser.END_DOCUMENT) xml.next()
            require(xml.name == "image-catalog" && xml.getAttributeValue(null, "version") == "1")
            while (xml.next() != XmlPullParser.END_DOCUMENT) {
                if (xml.eventType != XmlPullParser.START_TAG) continue
                require(xml.depth == 2 && xml.name == "image" && images.size < 512)
                val name = xml.getAttributeValue(null, "name") ?: error("Missing image name")
                val id = xml.getAttributeResourceValue(null, "drawable", 0)
                require(name.isNotBlank() && name.toByteArray().size <= 1024 && name !in images && id != 0)
                require(resources.getResourceTypeName(id) == "drawable")
                images[name] = id
            }
        }
        return images
    }
}
