package dev.assetpipeline.androidhost

import android.view.View
import android.view.ViewGroup

/** A retired modal subtree cannot deliver editor, click or selection events. */
object NativeWindowScope {
    private fun id(view: View) = view.resources.getIdentifier("ap_native_window_scope", "id", view.context.packageName)
    fun bind(root: View, lease: DialogPolicy.Lease) {
        val tag = id(root)
        check(tag != 0) { "Host must include canonical window-scope resources" }
        val pending = java.util.ArrayDeque<View>()
        pending.add(root)
        var count = 0
        while (pending.isNotEmpty()) {
            if (++count > 8192) throw NativeViewState.BudgetExceeded()
            val view = pending.removeLast()
            view.setTag(tag, lease)
            if (view is ViewGroup) for (i in 0 until view.childCount) pending.add(view.getChildAt(i))
        }
    }
    fun allows(view: View?): Boolean {
        if (view == null) return true
        val tag = id(view)
        val lease = if (tag == 0) null else view.getTag(tag) as? DialogPolicy.Lease
        return lease == null || (lease.active && view.isAttachedToWindow && view.isShown && view.isEnabled &&
            CrystalBridge.debugSessionState() == HostSession.State.FOREGROUND)
    }
}

/** For listeners such as TextWatcher whose event has no View argument. */
open class CrystalWindowListener {
    private var owner: View? = null
    fun bindOwner(view: View) { owner = view }
    protected fun allowsWindowEvent() = NativeWindowScope.allows(owner)
}
