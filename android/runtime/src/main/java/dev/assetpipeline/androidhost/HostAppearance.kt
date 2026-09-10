package dev.assetpipeline.androidhost

import android.content.Context
import android.content.res.Configuration

/** The appearance the host is drawing in, for Crystal: dark when the attached
 * host's configuration (the activity's, which a delegate's night mode changes;
 * the application's when no host is attached) says night. An iOS host tells
 * Crystal the same through its trait collection; here Crystal asks before a
 * render, and a night-mode change recreates the activity, which renders again. */
object HostAppearance {
    const val DARK = 1
    const val LIGHT = 0
    const val UNKNOWN = -1
    @Volatile private var application: Context? = null
    @Volatile private var host: Any? = null

    @JvmStatic fun initialize(context: Context) { application = context.applicationContext }
    @JvmStatic fun attach(owner: Any) { host = owner }
    @JvmStatic fun detach(owner: Any) { if (host === owner) host = null }

    /** The night mode of a configuration as this object reports it. */
    @JvmStatic fun of(configuration: Configuration): Int =
        if (configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES) DARK else LIGHT

    /** DARK, LIGHT, or UNKNOWN before initialize. */
    @JvmStatic fun dark(): Int {
        val context = (host as? Context) ?: application ?: return UNKNOWN
        return of(context.resources.configuration)
    }
}
