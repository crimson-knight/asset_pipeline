package dev.assetpipeline.androidhost

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.android.material.chip.Chip
import dev.assetpipeline.androidhost.databinding.ActivityMainBinding

open class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private lateinit var study: StudySpec
    private var storyText: String = DEFAULT_STORY
    private val rendererRefreshHandler = Handler(Looper.getMainLooper())
    private var visible = false
    private lateinit var navigation: NativeNavigation
    private lateinit var screenHost: NativeScreenHost
    private var pendingUserAction = false
    private val rendererRefreshRunnable: Runnable = object : Runnable {
        override fun run() {
            if (visible && !isFinishing && !isDestroyed) {
                if (configureRendererCard(pendingUserAction)) pendingUserAction = false
                else rendererRefreshHandler.postDelayed(this, 32L)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val requestedAppearance = intent.getStringExtra(EXTRA_STUDY_APPEARANCE)?.lowercase()
        AppCompatDelegate.setDefaultNightMode(
            when (requestedAppearance) {
                "dark" -> AppCompatDelegate.MODE_NIGHT_YES
                "light" -> AppCompatDelegate.MODE_NIGHT_NO
                else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
            }
        )

        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        // API 35 draws edge-to-edge. Keep toolbar/content clear of system
        // bars and the keyboard while preserving Android's inset dispatch.
        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { view, insets ->
            val safe = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.ime())
            view.setPadding(safe.left, safe.top, safe.right, safe.bottom)
            insets
        }
        ViewCompat.requestApplyInsets(binding.root)

        val externalApp = intent.getStringExtra(EXTRA_APP_SLUG)
        study = if (externalApp != null) {
            StudySpec(externalApp, "Native application fixture", "Shared Crystal application",
                "P0", "external-app", "development-proof", "Application logic and native views supplied by an external entrypoint.")
        } else {
            StudyCatalog.bySlug(intent.getStringExtra(EXTRA_STUDY_SLUG))
        }
        val appearance = requestedAppearance ?: "system"
        storyText = intent.getStringExtra(EXTRA_STUDY_STORY) ?: DEFAULT_STORY

        binding.toolbar.subtitle = study.slug
        binding.studyTitle.text = study.title
        binding.studySubtitle.text = study.summary
        binding.mountTitle.text = study.renderer
        binding.mountSummary.text =
            "Host shell ready. This mount card is where the Crystal Android renderer attaches native study content for ${study.slug}."
        binding.footnote.text =
            "Validation status: ${study.status}. Story: $storyText. The screenshot ledger should only be promoted after this mount contains renderer output."

        addChip("Priority ${study.priority}")
        addChip("Lane ${study.lane}")
        addChip("Appearance $appearance")
        addChip("Status ${study.status}")

        CrystalBridge.initialize(context = applicationContext)
        CrystalBridge.attachHost(this)
        navigation = NativeNavigation(this)
        screenHost = NativeScreenHost(this, binding.rendererMount, binding.hostViewport, savedInstanceState)
        CrystalBridge.callbackObserver = { scheduleRendererRefresh() }
    }

    override fun onStart() {
        super.onStart()
        CrystalBridge.foregroundHost(this)
        visible = true
        configureRendererCard(true)
    }

    override fun onStop() {
        visible = false
        rendererRefreshHandler.removeCallbacks(rendererRefreshRunnable)
        CrystalBridge.backgroundHost(this)
        super.onStop()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (visible && ::binding.isInitialized && event.hasNoModifiers() && NativeSemantics.dispatchShortcut(binding.rendererMount, event, unmodifiedOnly = true)) return true
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchKeyShortcutEvent(event: KeyEvent): Boolean {
        if (visible && ::binding.isInitialized && NativeSemantics.dispatchShortcut(binding.rendererMount, event)) return true
        return super.dispatchKeyShortcutEvent(event)
    }

    override fun onDestroy() {
        rendererRefreshHandler.removeCallbacks(rendererRefreshRunnable)
        screenHost.close()
        binding.rendererMount.removeAllViews()
        CrystalBridge.detachHost(this)
        super.onDestroy()
    }

    private fun scheduleRendererRefresh() {
        pendingUserAction = pendingUserAction || CrystalBridge.refreshCause == CrystalBridge.RefreshCause.ACTION
        rendererRefreshHandler.removeCallbacks(rendererRefreshRunnable)
        rendererRefreshHandler.postDelayed(rendererRefreshRunnable, 250L)
    }

    private fun addChip(text: String) {
        val chip = Chip(this).apply {
            this.text = text
            isCheckable = false
            isClickable = false
        }
        binding.chipGroup.addView(chip)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        screenHost.saveState(outState)
        super.onSaveInstanceState(outState)
    }

    fun debugViewStateCounts() = screenHost.deferredRefreshes to screenHost.restoredEntries
    fun debugSkippedViewState() = screenHost.skippedSnapshots
    fun debugViewport() = screenHost.lastViewport

    private fun configureRendererCard(userAction: Boolean = false): Boolean {
        binding.rendererCard.apply {
            strokeWidth = resources.displayMetrics.density.times(1f).toInt()
            radius = resources.displayMetrics.density.times(28f)
        }

        if (!screenHost.render(study.slug, userAction)) return false

        binding.mountSummary.text =
            "Renderer mount live. This study is being drawn by the Crystal Android renderer for ${study.slug}."
        binding.footnote.text =
            "Validation status: ${study.status}. Story: $storyText. Review renderer output against Material 3 expectations before promoting the ledger."
        navigation.synchronize()
        return true
    }

    companion object {
        const val EXTRA_STUDY_SLUG = "study_slug"
        const val EXTRA_APP_SLUG = "app_slug"
        const val EXTRA_STUDY_APPEARANCE = "study_appearance"
        const val EXTRA_STUDY_STORY = "study_story"

        private const val DEFAULT_STORY = "Cross-platform showcase shell"
    }
}
