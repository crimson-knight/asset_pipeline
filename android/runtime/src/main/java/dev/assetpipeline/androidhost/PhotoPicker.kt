package dev.assetpipeline.androidhost

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.lifecycle.Lifecycle
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max

/** A photo from the library or the camera, as JPEG bytes Crystal polls for.
 * Polled, not callback-driven, the way the iOS bridge is: a pick parks its
 * result here and the application's host tick drains it through state, take
 * and reset. One pick at a time. The library uses the system photo picker
 * (no permission); the camera uses TakePicture into a file under the private
 * cache, which needs the application's manifest to declare a FileProvider
 * with authority "<package>.assetpipeline.photos" over ap_photo_paths. */
object PhotoPicker {
    const val SOURCE_LIBRARY = 0
    const val SOURCE_CAMERA = 1
    const val STATE_IDLE = 0
    const val STATE_ACTIVE = 1
    const val STATE_READY = 2
    const val STATE_CANCELLED = 3
    const val STATE_ERROR = 4
    const val MAX_BYTES = 10 * 1024 * 1024

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { task -> Thread(task, "asset-pipeline-photos").apply { isDaemon = true } }
    private var host: ComponentActivity? = null
    private var library: ActivityResultLauncher<PickVisualMediaRequest>? = null
    private var camera: ActivityResultLauncher<Uri>? = null
    private var epoch = 0
    private var state = STATE_IDLE
    private var bytes: ByteArray? = null
    private var width = 0
    private var height = 0
    private var error = ""
    private var maxDimension = 2000
    private var quality = 80
    private var captureUri: Uri? = null
    private var launches = 0

    private fun checkMain() { check(Looper.myLooper() == Looper.getMainLooper()) { "Photo picking runs on the main looper" } }

    private sealed class Outcome
    private class Encoded(val bytes: ByteArray, val width: Int, val height: Int) : Outcome()
    private class Failure(val reason: String) : Outcome()

    /** Registers both launchers with the Activity's result registry, before it starts. */
    @JvmStatic fun attach(owner: ComponentActivity) {
        checkMain()
        if (host === owner) return
        check(host == null && !owner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) { "Photo picker must attach to one surface before it starts" }
        host = owner
        val bound = epoch
        library = owner.activityResultRegistry.register("asset_pipeline.photos.library.$bound", owner, ActivityResultContracts.PickVisualMedia()) { uri ->
            if (host === owner && epoch == bound) deliver(owner, uri)
        }
        camera = owner.activityResultRegistry.register("asset_pipeline.photos.camera.$bound", owner, ActivityResultContracts.TakePicture()) { taken ->
            if (host === owner && epoch == bound) deliver(owner, if (taken) captureUri else null)
        }
    }

    @JvmStatic fun detach(owner: ComponentActivity) {
        checkMain()
        if (host !== owner) return
        host = null
        // Lifecycle-owned registrations unregister at ON_DESTROY; a recreation
        // re-registers under the same key and receives the outstanding result.
        library = null
        camera = null
        if (!owner.isChangingConfigurations) {
            epoch++
            if (state == STATE_ACTIVE) state = STATE_CANCELLED
        }
    }

    @JvmStatic fun close() { checkMain(); host = null; library = null; camera = null; epoch++; reset() }

    @JvmStatic fun available(source: Int): Boolean {
        checkMain()
        val owner = host ?: return false
        return when (source) {
            SOURCE_LIBRARY -> library != null
            SOURCE_CAMERA -> camera != null && owner.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) && captureAuthority(owner) != null
            else -> false
        }
    }

    /** Presents the picker. False when one is active, the source is unavailable, or the platform refused. */
    @JvmStatic fun begin(source: Int, maxDimension: Int, quality: Int): Boolean {
        checkMain()
        val owner = host ?: return false
        if (state == STATE_ACTIVE) return false
        if (maxDimension !in 64..8192 || quality !in 1..100) return false
        this.maxDimension = maxDimension
        this.quality = quality
        bytes = null; width = 0; height = 0; error = ""
        return when (source) {
            SOURCE_LIBRARY -> {
                val launcher = library ?: return false
                state = STATE_ACTIVE
                launches++
                launcher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                true
            }
            SOURCE_CAMERA -> {
                val launcher = camera ?: return false
                val target = captureTarget(owner) ?: return false
                captureUri = target
                state = STATE_ACTIVE
                launches++
                launcher.launch(target)
                true
            }
            else -> false
        }
    }

    private fun captureAuthority(context: Context): String? {
        val authority = "${context.packageName}.assetpipeline.photos"
        return if (context.packageManager.resolveContentProvider(authority, 0) != null) authority else null
    }

    private fun captureTarget(context: Context): Uri? {
        val authority = captureAuthority(context) ?: return null
        val directory = File(context.cacheDir, "ap_photos").apply { mkdirs() }
        return try { FileProvider.getUriForFile(context, authority, File(directory, "capture.jpg")) } catch (_: IllegalArgumentException) { null }
    }

    private fun deliver(context: Context, uri: Uri?) {
        if (uri == null) { state = STATE_CANCELLED; return }
        val app = context.applicationContext
        val dimension = maxDimension
        val jpegQuality = quality
        val bound = epoch
        worker.execute {
            val outcome = try { encode(app, uri, dimension, jpegQuality) } catch (error: Exception) { Failure(error.javaClass.simpleName) }
            main.post {
                if (epoch != bound || state != STATE_ACTIVE) return@post
                when (outcome) {
                    is Encoded -> { bytes = outcome.bytes; width = outcome.width; height = outcome.height; state = STATE_READY }
                    is Failure -> {
                        // The reason only; never a URI or a path.
                        Log.w("APPhotos", "Photo could not be encoded: " + outcome.reason)
                        error = outcome.reason; state = STATE_ERROR
                    }
                }
            }
        }
    }

    /** Decodes, honors the EXIF orientation, fits the longest edge to maxDimension, encodes JPEG. */
    private fun encode(context: Context, uri: Uri, maxDimension: Int, quality: Int): Outcome {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        // A bounds pass returns no bitmap by design; only a missing stream is unreadable.
        val probe = resolver.openInputStream(uri) ?: return Failure("unreadable")
        probe.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return Failure("not an image")
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxDimension) sample *= 2
        val source = resolver.openInputStream(uri) ?: return Failure("unreadable")
        val decoded = source.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) }
            ?: return Failure("undecodable")
        val rotation = resolver.openInputStream(uri)?.use { stream ->
            when (ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } ?: 0f
        val longest = max(decoded.width, decoded.height)
        val scale = if (longest > maxDimension) maxDimension.toFloat() / longest else 1f
        val matrix = Matrix().apply { if (scale != 1f) postScale(scale, scale); if (rotation != 0f) postRotate(rotation) }
        val fitted = if (scale != 1f || rotation != 0f) Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true) else decoded
        val out = ByteArrayOutputStream()
        check(fitted.compress(Bitmap.CompressFormat.JPEG, quality, out)) { "encode failed" }
        val data = out.toByteArray()
        if (data.size > MAX_BYTES) return Failure("too large")
        return Encoded(data, fitted.width, fitted.height)
    }

    // Polled by Crystal on the main looper.
    @JvmStatic fun state(): Int { checkMain(); return state }
    @JvmStatic fun bytes(): ByteArray? { checkMain(); return if (state == STATE_READY) bytes else null }
    @JvmStatic fun width(): Int { checkMain(); return width }
    @JvmStatic fun height(): Int { checkMain(); return height }
    @JvmStatic fun errorBytes(): ByteArray { checkMain(); return error.toByteArray(Charsets.UTF_8) }
    @JvmStatic fun reset() { checkMain(); state = STATE_IDLE; bytes = null; width = 0; height = 0; error = ""; captureUri = null }

    fun debugLaunches(): Int { checkMain(); return launches }
    /** Feeds a URI through the same path a picker result takes, for tests that do not drive the system UI. */
    fun debugDeliver(uri: Uri) {
        checkMain()
        check(state != STATE_ACTIVE) { "a pick is active" }
        bytes = null; width = 0; height = 0; error = ""
        state = STATE_ACTIVE
        deliver(requireNotNull(host) { "no host" }, uri)
    }
}
