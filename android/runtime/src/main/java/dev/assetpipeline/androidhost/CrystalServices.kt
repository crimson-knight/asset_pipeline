package dev.assetpipeline.androidhost

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import java.util.concurrent.Executors

object CrystalServices {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { task -> Thread(task, "asset-pipeline-storage").apply { isDaemon = true } }
    private val networkWorker = Executors.newFixedThreadPool(4) { task -> Thread(task, "asset-pipeline-http").apply { isDaemon = true } }
    private val secretsWorker = Executors.newSingleThreadExecutor { task -> Thread(task, "asset-pipeline-secrets").apply { isDaemon = true } }
    private val filesWorker = Executors.newSingleThreadExecutor { task -> Thread(task, "asset-pipeline-files").apply { isDaemon = true } }
    private val notificationsWorker = Executors.newSingleThreadExecutor { task -> Thread(task, "asset-pipeline-notifications").apply { isDaemon = true } }
    private val http = PlatformHttp()
    private var storage: PrivateStorage? = null
    private var secrets: PrivateSecrets? = null
    private var files: PrivateFiles? = null
    private var notifications: PlatformNotifications? = null
    private var closed = false
    private var networkPermission = false
    private val queue = ServiceQueue(worker, { task -> check(main.post(task)) { "Android main looper stopped" } }, ::checkMain, { id, reply ->
        check(completeNative(id, reply.status.wire, reply.data)) { "Crystal service completion failed" }
    })
    private val networkQueue = ServiceQueue(networkWorker, { task -> check(main.post(task)) { "Android main looper stopped" } }, ::checkMain, { id, reply ->
        check(completeNative(id, reply.status.wire, reply.data)) { "Crystal HTTP completion failed" }
    })
    private val secretsQueue = ServiceQueue(secretsWorker, { task -> check(main.post(task)) { "Android main looper stopped" } }, ::checkMain, { id, reply ->
        check(completeNative(id, reply.status.wire, reply.data)) { "Crystal secrets completion failed" }
    })

    private val filesQueue = ServiceQueue(filesWorker, { task -> check(main.post(task)) { "Android main looper stopped" } }, ::checkMain, { id, reply ->
        check(completeNative(id, reply.status.wire, reply.data)) { "Crystal file completion failed" }
    })
    private val notificationsQueue = ServiceQueue(notificationsWorker, { task -> check(main.post(task)) { "Android main looper stopped" } }, ::checkMain, { id, reply ->
        check(completeNative(id, reply.status.wire, reply.data)) { "Crystal notification completion failed" }
    })
    private val permissionRequests = PermissionRequests(
        { task -> check(main.post(task)) { "Android main looper stopped" } }, ::checkMain,
        { flight -> val service = notifications; if (service == null) ServiceReply(ServiceStatus.UNAVAILABLE) else service.requestPermission(flight) },
        { id, reply -> check(completeNative(id, reply.status.wire, reply.data)) { "Crystal permission completion failed" } },
    )

    private fun checkMain() { check(Looper.myLooper() == Looper.getMainLooper()) { "Service dispatch must run on the main looper" } }
    fun initialize(context: Context) {
        checkMain()
        check(!closed) { "Android services are closed" }
        if (storage == null) storage = PrivateStorage(context.applicationContext)
        if (secrets == null) secrets = PrivateSecrets(context.applicationContext)
        if (files == null) files = PrivateFiles(context.applicationContext)
        AppDirectories.initialize(context.applicationContext)
        BundledAssets.initialize(context.applicationContext)
        if (notifications == null) notifications = PlatformNotifications(context.applicationContext)
        networkPermission = context.checkSelfPermission(android.Manifest.permission.INTERNET) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }
    @JvmStatic fun submitStorage(id: Long, operation: Int, key: ByteArray, value: ByteArray): Boolean {
        checkMain()
        val store = storage ?: return false
        if (key.size > 512 || value.size > 1_048_576) return false
        val ownedKey = key.copyOf()
        val ownedValue = value.copyOf()
        return queue.submit(id) { store.execute(operation, ownedKey, ownedValue) }
    }
    @JvmStatic fun submitHttp(id: Long, packet: ByteArray): Boolean {
        checkMain()
        if (closed || storage == null || packet.size > HttpWire.MAX_PACKET) return false
        if (!networkPermission) return networkQueue.submit(id) { ServiceReply(ServiceStatus.PERMISSION_DENIED) }
        val operation = http.Operation(packet.copyOf())
        return networkQueue.submit(id, operation::cancel, operation::execute)
    }
    @JvmStatic fun submitSecrets(id: Long, operation: Int, key: ByteArray, value: ByteArray): Boolean {
        checkMain()
        val vault = secrets ?: return false
        if (closed || key.size > SecretVaultCodec.MAX_KEY || value.size > SecretVaultCodec.MAX_VALUE) return false
        val ownedKey = key.copyOf()
        val ownedValue = value.copyOf()
        return secretsQueue.submit(id) { vault.execute(operation, ownedKey, ownedValue) }
    }
    @JvmStatic fun submitFiles(id: Long, operation: Int, path: ByteArray, data: ByteArray): Boolean {
        checkMain()
        val store = files ?: return false
        if (closed || path.size > FilePolicy.MAX_PATH || data.size > FilePolicy.MAX_DATA) return false
        val ownedPath = path.copyOf()
        val ownedData = data.copyOf()
        return filesQueue.submit(id) { store.execute(operation, ownedPath, ownedData) }
    }
    @JvmStatic fun submitNotifications(id: Long, packet: ByteArray): Boolean {
        checkMain()
        val service = notifications ?: return false
        if (closed || packet.size > NotificationWire.MAX_PACKET) return false
        val request = try { NotificationWire.decode(packet.copyOf()) } catch (_: Exception) {
            return notificationsQueue.submit(id) { ServiceReply(ServiceStatus.INVALID_INPUT) }
        }
        if (request.operation == 1) return permissionRequests.submit(id)
        return notificationsQueue.submit(id) { service.execute(request) }
    }
    fun attachHost(owner: Any) { checkMain(); if (owner is ComponentActivity) { notifications?.attach(owner, permissionRequests); PhotoPicker.attach(owner) } }
    fun detachHost(owner: Any) { checkMain(); if (owner is ComponentActivity) { notifications?.detach(owner, permissionRequests); PhotoPicker.detach(owner) } }
    @JvmStatic fun cancel(id: Long) { queue.cancel(id); networkQueue.cancel(id); secretsQueue.cancel(id); filesQueue.cancel(id); notificationsQueue.cancel(id); permissionRequests.cancel(id) }
    fun pendingCount(): Int = queue.pendingCount + networkQueue.pendingCount + secretsQueue.pendingCount + filesQueue.pendingCount + notificationsQueue.pendingCount + permissionRequests.pendingCount
    fun close() {
        checkMain()
        if (closed) return
        closed = true
        queue.close()
        networkQueue.close()
        networkWorker.shutdown()
        secretsQueue.close()
        secretsWorker.shutdown()
        secrets = null
        filesQueue.close()
        filesWorker.shutdown()
        files = null
        permissionRequests.close()
        notifications?.close()
        notificationsQueue.close()
        notificationsWorker.shutdown()
        notifications = null
        // This runs after all accepted work. Pending replies still drain on main.
        val closing = storage
        storage = null
        worker.execute { closing?.close() }
        worker.shutdown()
    }
    @JvmStatic private external fun completeNative(id: Long, status: Int, data: ByteArray): Boolean
}
