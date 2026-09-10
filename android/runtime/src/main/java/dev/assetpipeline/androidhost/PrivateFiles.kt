package dev.assetpipeline.androidhost

import android.content.Context
import android.os.Looper
import android.os.UserManager

/** App-private binary files, not protected secrets or user-selected documents.
 * The native backend opens each path component relative to directory descriptors
 * and owns/closes all file descriptors before returning to this JVM worker.
 */
class PrivateFiles(context: Context, private val name: String = "asset_pipeline_files_v1") {
    private val app = context.applicationContext
    init { require(name.matches(Regex("[A-Za-z0-9_-]{1,64}"))) }

    fun execute(operation: Int, path: ByteArray, data: ByteArray): ServiceReply {
        check(Looper.myLooper() != Looper.getMainLooper()) { "File operations must run off the main looper" }
        try { FilePolicy.validate(operation, path, data.size) } catch (_: Exception) { return ServiceReply(ServiceStatus.INVALID_INPUT) }
        return try {
            if (app.isDeviceProtectedStorage || !app.getSystemService(UserManager::class.java).isUserUnlocked) return ServiceReply(ServiceStatus.UNAVAILABLE)
            val result = executeNative(app.filesDir.absolutePath.toByteArray(Charsets.UTF_8), name.toByteArray(Charsets.UTF_8), path, data, operation)
            check(result.isNotEmpty() && result.size <= FilePolicy.MAX_DATA + 1)
            val status = ServiceStatus.entries.first { it.wire == result[0].toInt() }
            ServiceReply(status, result.copyOfRange(1, result.size))
        } catch (_: UnsatisfiedLinkError) { ServiceReply(ServiceStatus.UNAVAILABLE)
        } catch (_: SecurityException) { ServiceReply(ServiceStatus.PERMISSION_DENIED)
        } catch (_: Exception) { ServiceReply(ServiceStatus.IO) }
    }

    companion object {
        @JvmStatic private external fun executeNative(root: ByteArray, namespace: ByteArray, path: ByteArray, data: ByteArray, operation: Int): ByteArray
    }
}
