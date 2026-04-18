package dev.assetpipeline.androidhost

import android.content.Context
import android.view.View

object CrystalBridge {
    private var didLoad = false

    fun initialize() {
        if (didLoad) return
        System.loadLibrary("android_material_host")
        didLoad = true
    }

    external fun renderStudy(context: Context, slug: String): View?
}
