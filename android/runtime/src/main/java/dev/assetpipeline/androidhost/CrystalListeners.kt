package dev.assetpipeline.androidhost

import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.KeyEvent
import android.widget.TextView
import android.widget.AdapterView
import android.widget.CompoundButton
import android.widget.RadioGroup
import android.widget.SearchView
import android.widget.SeekBar

class CrystalClickListener(private val callbackId: Long) : View.OnClickListener {
    override fun onClick(v: View?) {
        if (!NativeWindowScope.allows(v)) return
        CrystalBridge.dispatchVoidCallback(callbackId)
    }
}

class CrystalCheckedChangeListener(private val callbackId: Long) : CompoundButton.OnCheckedChangeListener {
    override fun onCheckedChanged(buttonView: CompoundButton?, isChecked: Boolean) {
        if (!NativeWindowScope.allows(buttonView)) return
        CrystalBridge.dispatchBoolCallback(callbackId, isChecked)
    }
}

class CrystalSeekBarChangeListener(private val callbackId: Long) : SeekBar.OnSeekBarChangeListener {
    override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
        if (!NativeWindowScope.allows(seekBar)) return
        CrystalBridge.dispatchFloatCallback(callbackId, progress.toDouble())
    }

    override fun onStartTrackingTouch(seekBar: SeekBar?) {
    }

    override fun onStopTrackingTouch(seekBar: SeekBar?) {
    }
}

class CrystalTextWatcher(private val callbackId: Long) : CrystalWindowListener(), TextWatcher {
    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {
    }

    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
    }

    override fun afterTextChanged(s: Editable?) {
        if (!allowsWindowEvent()) return
        CrystalBridge.dispatchStringCallback(callbackId, s?.toString() ?: "")
    }
}

class CrystalEditorActionListener(private val callbackId: Long) : TextView.OnEditorActionListener {
    override fun onEditorAction(view: TextView, actionId: Int, event: KeyEvent?): Boolean {
        if (!NativeWindowScope.allows(view)) return false
        return when (EditorActions.interpret(actionId, event?.keyCode, event?.action, event?.repeatCount ?: 0)) {
            EditorActions.SUBMIT -> {
                CrystalBridge.dispatchStringCallback(callbackId, view.text.toString())
                // The host schedules this after the editor callback returns.
                CrystalBridge.callbackObserver?.invoke()
                true
            }
            EditorActions.CONSUME -> true
            else -> false
        }
    }
}

class CrystalRadioGroupCheckedChangeListener(private val callbackId: Long) : RadioGroup.OnCheckedChangeListener {
    override fun onCheckedChanged(group: RadioGroup?, checkedId: Int) {
        if (!NativeWindowScope.allows(group)) return
        CrystalBridge.dispatchIntCallback(callbackId, checkedId)
    }
}

class CrystalSearchQueryListener(
    private val changeCallbackId: Long,
    private val submitCallbackId: Long
) : CrystalWindowListener(), SearchView.OnQueryTextListener {
    override fun onQueryTextSubmit(query: String?): Boolean {
        if (!allowsWindowEvent()) return false
        if (submitCallbackId != 0L) {
            CrystalBridge.dispatchStringCallback(submitCallbackId, query ?: "")
        }
        return false
    }

    override fun onQueryTextChange(newText: String?): Boolean {
        if (!allowsWindowEvent()) return false
        if (changeCallbackId != 0L) {
            CrystalBridge.dispatchStringCallback(changeCallbackId, newText ?: "")
        }
        return false
    }
}

class CrystalSearchCloseListener(private val callbackId: Long) : CrystalWindowListener(), SearchView.OnCloseListener {
    override fun onClose(): Boolean {
        if (!allowsWindowEvent()) return false
        if (callbackId != 0L) {
            CrystalBridge.dispatchVoidCallback(callbackId)
        }
        return false
    }
}

class CrystalItemSelectedListener(private val callbackId: Long) : AdapterView.OnItemSelectedListener {
    private var hasSeenInitialSelection = false

    override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
        if (!NativeWindowScope.allows(parent)) return
        if (!hasSeenInitialSelection) {
            hasSeenInitialSelection = true
            return
        }
        CrystalBridge.dispatchIntCallback(callbackId, position)
    }

    override fun onNothingSelected(parent: AdapterView<*>?) {
    }
}
