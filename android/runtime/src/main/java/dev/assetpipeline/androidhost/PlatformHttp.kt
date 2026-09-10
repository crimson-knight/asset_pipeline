package dev.assetpipeline.androidhost

import java.io.IOException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import okhttp3.Call
import okhttp3.ConnectionPool
import okhttp3.OkHttpClient

/** Constructed lazily on a worker: Android owns TLS, trust anchors and hostname
 * verification. No trust manager/hostname verifier override, cookie jar, cache,
 * logging interceptor or implicit redirect/retry carrying credentials elsewhere.
 */
class PlatformHttp {
    private val client by lazy {
        OkHttpClient.Builder().followRedirects(false).followSslRedirects(false)
            .retryOnConnectionFailure(false)
            .connectionPool(ConnectionPool(0, 1, TimeUnit.SECONDS))
            .connectTimeout(30, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS).build()
    }

    inner class Operation(private val packet: ByteArray) {
        private val cancelled = AtomicBoolean(false)
        private val active = AtomicReference<Call?>(null)
        fun cancel() { cancelled.set(true); active.get()?.cancel() }
        fun execute(): ServiceReply {
            if (cancelled.get()) return ServiceReply(ServiceStatus.CANCELLED)
            return try {
                val input = HttpWire.decode(packet)
                val call = client.newCall(input.request)
                call.timeout().timeout(input.timeoutMs.toLong(), TimeUnit.MILLISECONDS)
                active.set(call)
                // Covers cancellation between the initial check and publication.
                if (cancelled.get()) call.cancel()
                call.execute().use { ServiceReply(ServiceStatus.OK, HttpWire.encode(it)) }
            } catch (_: SecurityException) {
                ServiceReply(ServiceStatus.PERMISSION_DENIED)
            } catch (_: IllegalArgumentException) {
                ServiceReply(ServiceStatus.INVALID_INPUT)
            } catch (_: IOException) {
                ServiceReply(if (cancelled.get()) ServiceStatus.CANCELLED else ServiceStatus.NETWORK)
            } finally { active.set(null) }
        }
    }
}
