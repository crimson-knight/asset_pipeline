package dev.assetpipeline.androidhost

import android.graphics.Typeface

/** Pure rules for typefaces: which family names an application may register
 * or ask for, and which style bits apply to a registered face. */
object FontPolicy {
    const val MAX_FAMILY_LENGTH = 128

    fun validFamily(name: String): Boolean =
        name.isNotBlank() && name.length <= MAX_FAMILY_LENGTH && name.none { it.code < 32 || it.code == 127 }

    /** The platform default, whatever the style. */
    fun system(name: String): Boolean = name.isBlank() || name == "system"

    /** A registered face carries its own weight; only italic may be synthesized on it. */
    fun registeredStyle(style: Int): Int = style and Typeface.ITALIC
}
