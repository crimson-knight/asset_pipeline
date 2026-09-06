package dev.assetpipeline.androidhost

import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.content.res.AppCompatResources
import com.google.android.material.appbar.MaterialToolbar

/** Crystal owns the stack. Android owns lifecycle-aware system Back dispatch.
 * Disabled at root, allowing system back-to-home and its predictive animation.
 * In-app transitions commit on Back; interactive in-app animations are not provided.
 */
class NativeNavigation(activity: AppCompatActivity) {
    private val back = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() {
            // Re-read current state: a deferred render may not have happened yet.
            if (!CrystalBridge.navigateBack()) {
                isEnabled = false
                activity.onBackPressedDispatcher.onBackPressed()
            }
        }
    }

    init {
        activity.onBackPressedDispatcher.addCallback(activity, back)
        CrystalBridge.navigationObserver = { synchronize() }
    }

    fun synchronize() { back.isEnabled = CrystalBridge.canNavigateBack() }

    companion object {
        @JvmStatic fun configureToolbar(toolbar: MaterialToolbar, callbackId: Long, color: Int) {
            toolbar.navigationIcon = requireNotNull(AppCompatResources.getDrawable(
                toolbar.context, androidx.appcompat.R.drawable.abc_ic_ab_back_material
            )).mutate().apply { setTint(color) }
            toolbar.setNavigationContentDescription(androidx.appcompat.R.string.abc_action_bar_up_description)
            toolbar.setNavigationOnClickListener { CrystalBridge.dispatchVoidCallback(callbackId) }
        }
    }
}
