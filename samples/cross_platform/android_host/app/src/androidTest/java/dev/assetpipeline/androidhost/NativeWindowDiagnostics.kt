package dev.assetpipeline.androidhost

import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice

/**
 * Failure-only description of the window that holds focus and of every window
 * this process owns. A wait that times out then names the window that took
 * focus (its type, flags, owner and content) instead of only reporting that
 * the expected window never received it. Never called on a passing path.
 */
object NativeWindowDiagnostics {
    fun describe(): String {
        val focus = try { focusRecord() } catch (failure: Throwable) { "focus unavailable: ${failure.javaClass.simpleName}" }
        val roots = try { processRoots() } catch (failure: Throwable) { "roots unavailable: ${failure.javaClass.simpleName}" }
        return "$focus || roots: $roots"
    }

    /** The focused window from the window manager, with its own record when it can be found. */
    private fun focusRecord(): String {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        val displays = device.executeShellCommand("dumpsys window displays").lineSequence()
            .filter { it.contains("mCurrentFocus") || it.contains("mFocusedApp") }
            .joinToString(" | ") { it.trim() }
        val focused = Regex("mCurrentFocus=Window\\{([0-9a-f]+) ").find(displays)?.groupValues?.get(1) ?: return displays
        val lines = device.executeShellCommand("dumpsys window windows").lines()
        val start = lines.indexOfFirst { it.contains("Window{$focused ") }
        if (start < 0) return displays
        val wanted = listOf("mOwnerUid", "mAttrs", "package=", "Frames:", "mViewVisibility", "mAttachedWindow", "mParentWindow")
        val record = lines.drop(start + 1).takeWhile { !it.contains("Window #") }
            .filter { line -> wanted.any { line.contains(it) } }
            .joinToString(" | ") { it.trim() }
        return "$displays | focused window: $record"
    }

    /** Class names of a view's children, nested to [depth], so a popup's real content is named. */
    private fun describeChildren(view: View, depth: Int): List<String> {
        if (depth == 0 || view !is ViewGroup) return emptyList()
        return (0 until view.childCount).map { index ->
            val child = view.getChildAt(index)
            val inner = describeChildren(child, depth - 1)
            if (inner.isEmpty()) child.javaClass.name else "${child.javaClass.name}$inner"
        }
    }

    /** Every attached view root of this process, read from the registry Espresso itself uses. */
    private fun processRoots(): String {
        var description = ""
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val global = Class.forName("android.view.WindowManagerGlobal")
            val instance = global.getMethod("getInstance").invoke(null)
            val views = global.getDeclaredField("mViews").apply { isAccessible = true }.get(instance) as List<*>
            val params = global.getDeclaredField("mParams").apply { isAccessible = true }.get(instance) as List<*>
            description = views.indices.joinToString("; ") { index ->
                val view = views[index] as View
                val layout = params[index] as WindowManager.LayoutParams
                val content = describeChildren(view, depth = 3)
                val focusable = layout.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE == 0
                "${view.javaClass.simpleName}[title=${layout.title} type=${layout.type} focusable=$focusable" +
                    " windowFocus=${view.hasWindowFocus()} visible=${view.visibility == View.VISIBLE}" +
                    " size=${view.width}x${view.height} content=$content]"
            }
        }
        return description
    }
}
