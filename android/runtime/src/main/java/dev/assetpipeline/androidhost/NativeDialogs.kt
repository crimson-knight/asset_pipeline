package dev.assetpipeline.androidhost

import android.app.Activity
import android.content.Context
import android.content.DialogInterface
import android.os.Bundle
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.widget.Button
import androidx.appcompat.app.AlertDialog
import androidx.core.view.ViewCompat
import com.google.android.material.color.MaterialColors
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import org.json.JSONObject

/** A zero-layout declaration. Its callback tokens belong to the Crystal tree. */
class NativeDialogAnchor(context: Context) : View(context) {
    var descriptor: DialogPolicy.Descriptor? = null
        internal set
    init { visibility = GONE; isSaveEnabled = false; isSaveFromParentEnabled = false }
}

object NativeDialogs {
    @JvmStatic fun configure(anchor: View, packet: String) {
        check(Looper.myLooper() == Looper.getMainLooper())
        require(anchor is NativeDialogAnchor && packet.toByteArray(Charsets.UTF_8).size <= DialogPolicy.MAX_PACKET_BYTES)
        anchor.descriptor = try {
            val json = JSONObject(packet)
            require(json.length() == 5 && json.get("version") == 1)
            val actions = json.getJSONArray("actions")
            require(actions.length() in 1..3)
            fun token(value: Any): Long { require(value is Long || value is Int); return (value as Number).toLong() }
            DialogPolicy.validate(DialogPolicy.Descriptor(json.get("title") as String, json.get("message") as String,
                (0 until actions.length()).map { index ->
                    val action = actions.getJSONObject(index)
                    require(action.length() == 3)
                    DialogPolicy.Action(action.get("label") as String, action.get("style") as String, token(action.get("token")))
                }, token(json.get("cancel"))))
        } catch (_: Exception) { throw IllegalArgumentException("Invalid Android dialog descriptor") }
    }
}

/** One modal window per canonical screen host. Never saves a View or callback.
 * Render replacement/background/destroy silently retire the old window BEFORE
 * Crystal releases its tokens. Only actual user actions/cancellation dispatch.
 */
class NativeDialogHost(private val activity: Activity, savedState: Bundle?) {
    companion object { private const val STATE = "asset_pipeline.native_dialog.v1" }
    private data class Presented(val dialog: AlertDialog, val anchor: NativeDialogAnchor,
        val descriptor: DialogPolicy.Descriptor, val identity: String, val buttons: List<Button>,
        val lease: DialogPolicy.Lease = DialogPolicy.Lease())
    private var current: Presented? = null
    private var focus: DialogPolicy.Focus? = decodeFocus(NativeViewState.raw(savedState, STATE) as? Bundle)
    private var closed = false
    private val sheets = NativeSheetHost(activity, savedState)
    private fun main() = check(Looper.myLooper() == Looper.getMainLooper()) { "Native dialogs require the main looper" }
    val activeCount: Int get() = (if (current?.lease?.active == true) 1 else 0) + sheets.activeCount
    val focusedEditor get() = sheets.focusedEditor
    fun requestSheetDismiss(anchor: NativeSheetAnchor) = sheets.requestDismiss(anchor)

    private fun decodeFocus(bundle: Bundle?): DialogPolicy.Focus? {
        val identity = NativeViewState.raw(bundle, "identity") as? String ?: return null
        val signature = NativeViewState.raw(bundle, "signature") as? String ?: return null
        val index = NativeViewState.raw(bundle, "index") as? Int ?: return null
        return DialogPolicy.Focus(identity, signature, index).takeIf { it.valid() }
    }
    private fun captureFocus() {
        current?.let { shown ->
            val index = shown.buttons.indexOfFirst { it.hasFocus() }
            focus = if (index >= 0) DialogPolicy.Focus(shown.identity, shown.descriptor.signature, index).takeIf { it.valid() } else null
        }
    }
    fun saveState(out: Bundle) {
        main(); captureFocus()
        sheets.saveState(out)
        focus?.let { saved -> out.putBundle(STATE, Bundle().apply {
            putString("identity", saved.identity); putString("signature", saved.signature); putInt("index", saved.index)
        }) }
    }
    fun suspend() { main(); captureFocus(); retire(); sheets.suspend() }
    fun beforeRender() { main(); check(!closed); sheets.completePending(); suspend() }
    fun beforeBackground() { main(); sheets.completePending(); suspend() }
    fun close() { main(); retire(); sheets.close(); focus = null; closed = true }
    private fun retire() {
        val previous = current ?: return
        current = null
        previous.lease.retire()
        previous.dialog.setOnCancelListener(null)
        previous.dialog.setOnDismissListener(null)
        previous.buttons.forEach { it.setOnClickListener(null) }
        previous.dialog.dismiss()
    }
    private fun visibleParents(anchor: View, root: View): Boolean {
        var parent = anchor.parent as? View
        while (parent != null) {
            if (parent.visibility != View.VISIBLE) return false
            if (parent === root) return true
            parent = parent.parent as? View
        }
        return anchor === root
    }
    fun synchronize(root: View, route: String) {
        main(); check(!closed && current == null)
        check(CrystalBridge.debugSessionState() == HostSession.State.FOREGROUND)
        val declarations = NativeViewState.nodes(root).filter {
            ((it.view is NativeDialogAnchor && it.view.descriptor != null) ||
                (it.view is NativeSheetAnchor && it.view.descriptor != null)) && visibleParents(it.view, root) }
        require(declarations.size <= 1) { "Only one active native modal is supported per screen; sequence presentations explicitly" }
        val node = declarations.singleOrNull()
        val sheetIdentity = node?.takeIf { it.view is NativeSheetAnchor }?.let { SheetPolicy.identity(route, it.identity.address) }
        // A vanished/replaced declaration completes once after the old window
        // and controls retire. Rebuild before presenting anything its callback
        // may have changed; an ordinary same-identity refresh is silent.
        if (sheets.reconcile(sheetIdentity)) { focus = null; sheets.clearSnapshot(); return }
        if (node == null) { focus = null; sheets.clearSnapshot(); return }
        if (node.view is NativeSheetAnchor) { focus = null; sheets.present(node, route); return }
        sheets.clearSnapshot()
        val anchor = node.view as NativeDialogAnchor
        val descriptor = requireNotNull(anchor.descriptor)
        val identity = "${route.length}:$route${node.identity.address}"
        require(identity.toByteArray(Charsets.UTF_8).size <= 8192) { "Native dialog identity exceeds its bound" }
        val builder = MaterialAlertDialogBuilder(activity).setTitle(descriptor.title).setMessage(descriptor.message)
            .setCancelable(true)
        val available = mutableListOf(DialogInterface.BUTTON_POSITIVE, DialogInterface.BUTTON_NEUTRAL)
        if (descriptor.actions.none { it.style == "cancel" }) available.add(DialogInterface.BUTTON_NEGATIVE)
        val slots = descriptor.actions.map { action ->
            if (action.style == "cancel") DialogInterface.BUTTON_NEGATIVE else available.removeAt(0)
        }
        // Reserve the cancel slot independently of the declared action order.
        for ((index, action) in descriptor.actions.withIndex()) when (slots[index]) {
            DialogInterface.BUTTON_NEGATIVE -> builder.setNegativeButton(action.label, null)
            DialogInterface.BUTTON_POSITIVE -> builder.setPositiveButton(action.label, null)
            else -> builder.setNeutralButton(action.label, null)
        }
        val dialog = builder.create()
        try {
            dialog.setCanceledOnTouchOutside(true)
            dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN)
            dialog.show()
            val buttons = slots.map { requireNotNull(dialog.getButton(it)) }
            val shown = Presented(dialog, anchor, descriptor, identity, buttons)
            current = shown
            dialog.window?.decorView?.let { decor ->
                decor.isSaveFromParentEnabled = false
                NativeSemantics.metadata(anchor)?.let { NativeSemantics.decorate(decor, it) }
                ViewCompat.setAccessibilityPaneTitle(decor, NativeSemantics.metadata(anchor)?.label ?: descriptor.title)
            }
            for ((index, button) in buttons.withIndex()) {
                val action = descriptor.actions[index]
                button.minimumHeight = maxOf(button.minimumHeight, (48 * button.resources.displayMetrics.density).toInt())
                if (action.style == "destructive") button.setTextColor(MaterialColors.getColor(button, com.google.android.material.R.attr.colorError))
                NativeSemantics.dialogAction(button, DialogPolicy.actionTestId(NativeSemantics.testId(anchor), index))
                button.setOnClickListener { dispatch(shown, action.token) }
            }
            dialog.setOnCancelListener { dispatch(shown, descriptor.cancel) }
            dialog.setOnDismissListener { dispatch(shown, descriptor.cancel) }
            focus?.takeIf { it.matches(identity, descriptor) }?.let { saved ->
                buttons[saved.index].apply { isFocusableInTouchMode = true; requestFocus() }
            }
            focus = null
        } catch (error: Throwable) {
            try {
                if (current?.dialog === dialog) retire() else {
                    dialog.setOnCancelListener(null); dialog.setOnDismissListener(null)
                    dialog.dismiss()
                }
            } catch (cleanup: Throwable) { error.addSuppressed(cleanup) }
            throw error
        }
    }
    private fun dispatch(shown: Presented, token: Long) {
        main()
        if (current !== shown || !shown.lease.active || CrystalBridge.debugSessionState() != HostSession.State.FOREGROUND) return
        if (!shown.lease.consume()) return
        // Suppress the framework's queued onDismiss callback before dispatching
        // Crystal, whose action may remove this declaration or fail terminally.
        retire(); focus = null
        CrystalBridge.dispatchVoidCallback(token)
    }
}
