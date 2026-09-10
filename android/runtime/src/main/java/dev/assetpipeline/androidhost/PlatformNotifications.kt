package dev.assetpipeline.androidhost

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.Lifecycle
import org.xmlpull.v1.XmlPullParser

/** Local, immediate notifications only. No push, scheduling, foreground service,
 * permission-on-startup, or arbitrary channel creation. */
class PlatformNotifications(context: Context) {
    companion object {
        const val METADATA = "dev.assetpipeline.notification_channels"
        const val TAG = "asset_pipeline.local.v1"
    }
    private val context = context.applicationContext
    private val manager = this.context.getSystemService(NotificationManager::class.java)
    private val applicationInfo = this.context.packageManager.getApplicationInfo(this.context.packageName, PackageManager.GET_META_DATA)
    private val resource = applicationInfo.metaData?.getInt(METADATA, 0) ?: 0
    // A legacy target lets Android choose when to prompt on channel creation.
    // This adapter requires app-controlled timing, including on pre-33 devices.
    private val declared = applicationInfo.targetSdkVersion >= 33 && resource != 0 && (this.context.packageManager.getPackageInfo(this.context.packageName, PackageManager.GET_PERMISSIONS)
        .requestedPermissions?.contains(Manifest.permission.POST_NOTIFICATIONS) == true)
    private data class Channel(val id: String, val name: String, val description: String, val importance: Int)
    private data class Configuration(val icon: Int, val channels: List<Channel>)
    // Resources are parsed only for a post, on the service worker.
    private val configuration: Configuration by lazy { readConfiguration() }
    private var host: ComponentActivity? = null
    private var launcher: ActivityResultLauncher<String>? = null
    private var epoch = 0L
    private var launchedFlight: Long? = null

    private fun checkMain() { check(Looper.myLooper() == Looper.getMainLooper()) }
    fun attach(owner: ComponentActivity, requests: PermissionRequests) {
        checkMain()
        if (host === owner) return
        check(host == null && !owner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED))
        host = owner
        val bindingEpoch = epoch
        launcher = owner.activityResultRegistry.register("asset_pipeline.notifications.$bindingEpoch", owner, ActivityResultContracts.RequestPermission()) {
            // Re-query app-wide state; denial/dismissal isn't a grant. Discard
            // callbacks delivered to an obsolete Activity or a finished host.
            if (host === owner && epoch == bindingEpoch) {
                val flight = launchedFlight
                launchedFlight = null
                if (flight != null) requests.result(flight, permissionReply())
            }
        }
    }
    fun detach(owner: ComponentActivity, requests: PermissionRequests) {
        checkMain()
        if (host !== owner) return
        host = null
        // Lifecycle-owned registration unregisters at ON_DESTROY. Don't remove
        // it early: ActivityResultRegistry preserves outstanding launch state.
        launcher = null
        if (!owner.isChangingConfigurations) {
            epoch++
            launchedFlight = null
            requests.abandon()
        }
    }
    fun close() { checkMain(); launcher?.unregister(); launcher = null; host = null; launchedFlight = null; epoch++ }

    private fun enabled(): Boolean = manager.areNotificationsEnabled() &&
        (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
    private fun permissionReply() = if (!declared) ServiceReply(ServiceStatus.PERMISSION_DENIED)
        else ServiceReply(ServiceStatus.OK, byteArrayOf(if (enabled()) 1 else 0))

    /** Null means an asynchronous OS result is outstanding. No worker waits. */
    fun requestPermission(flight: Long): ServiceReply? {
        checkMain()
        if (!declared || Build.VERSION.SDK_INT < 33 || enabled()) return permissionReply()
        val owner = host
        if (owner == null || owner.isFinishing || owner.isDestroyed || !owner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))
            return ServiceReply(ServiceStatus.UNAVAILABLE)
        val active = launcher ?: return ServiceReply(ServiceStatus.UNAVAILABLE)
        launchedFlight = flight
        try { active.launch(Manifest.permission.POST_NOTIFICATIONS) }
        catch (error: Exception) { launchedFlight = null; throw error }
        return null
    }

    fun execute(request: NotificationWire.Request): ServiceReply {
        check(Looper.myLooper() != Looper.getMainLooper()) { "Notification manager work requires a worker" }
        if (!declared) return ServiceReply(ServiceStatus.PERMISSION_DENIED)
        if (request.operation == 3) {
            manager.cancel(TAG, request.id) // Idempotent; can cancel while permission is disabled.
            return ServiceReply(ServiceStatus.OK)
        }
        require(request.operation == 2)
        val config = configuration
        val declaredChannel = config.channels.singleOrNull { it.id == request.channel }
            ?: return ServiceReply(ServiceStatus.INVALID_INPUT)
        if (!enabled()) return ServiceReply(ServiceStatus.PERMISSION_DENIED)
        if (manager.getNotificationChannel(request.channel) == null) {
            val channel = NotificationChannel(declaredChannel.id, declaredChannel.name, declaredChannel.importance).apply {
                description = declaredChannel.description
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
        val channel = manager.getNotificationChannel(request.channel) ?: return ServiceReply(ServiceStatus.IO)
        if (channel.importance == NotificationManager.IMPORTANCE_NONE ||
            (channel.group?.let { manager.getNotificationChannelGroup(it)?.isBlocked } == true))
            return ServiceReply(ServiceStatus.PERMISSION_DENIED)
        val notification = Notification.Builder(context, request.channel)
            .setSmallIcon(config.icon).setContentTitle(request.title).setContentText(request.body)
            .setStyle(Notification.BigTextStyle().bigText(request.body))
            .setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE)
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { intent ->
            notification.setContentIntent(PendingIntent.getActivity(context, request.id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }
        manager.notify(TAG, request.id, notification.build())
        return ServiceReply(ServiceStatus.OK) // Accepted by Android, not proof of presentation/read.
    }

    private fun readConfiguration(): Configuration {
        require(resource != 0)
        context.resources.getXml(resource).use { xml ->
            while (xml.eventType != XmlPullParser.START_TAG && xml.eventType != XmlPullParser.END_DOCUMENT) xml.next()
            require(xml.name == "notification-channels")
            val icon = xml.getAttributeResourceValue(null, "smallIcon", 0)
            require(icon != 0 && context.resources.getResourceTypeName(icon) == "drawable")
            val channels = mutableListOf<Channel>()
            while (xml.next() != XmlPullParser.END_DOCUMENT) {
                if (xml.eventType != XmlPullParser.START_TAG) continue
                require(xml.depth == 2 && xml.name == "channel" && channels.size < 32)
                fun text(name: String): String {
                    val id = xml.getAttributeResourceValue(null, name, 0)
                    return if (id != 0) context.resources.getString(id) else xml.getAttributeValue(null, name) ?: ""
                }
                val id = text("id")
                val name = text("name")
                val description = text("description")
                val importance = text("importance").toInt()
                require(id.matches(Regex("[A-Za-z0-9][A-Za-z0-9_.-]{0,127}")) && channels.none { it.id == id })
                require(name.isNotBlank() && name.toByteArray().size <= 128 && !name.contains('\u0000'))
                require(description.toByteArray().size <= 1_024 && !description.contains('\u0000'))
                require(importance in 2..4)
                channels += Channel(id, name, description, importance)
            }
            return Configuration(icon, channels)
        }
    }
}
