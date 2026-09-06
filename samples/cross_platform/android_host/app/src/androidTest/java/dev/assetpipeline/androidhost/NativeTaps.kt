package dev.assetpipeline.androidhost

import android.os.SystemClock
import androidx.test.espresso.PerformException
import androidx.test.espresso.ViewInteraction
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.scrollTo

/**
 * Taps on a software-rendered emulator are occasionally dropped or land while
 * a smooth scroll is still moving the target. Retry a dropped tap a bounded
 * number of times; never relax what the test asserts afterwards.
 */
object NativeTaps {
    fun tap(interaction: () -> ViewInteraction, attempts: Int = 3) {
        var last: PerformException? = null
        repeat(attempts) { attempt ->
            try {
                interaction().perform(scrollTo(), click())
                return
            } catch (dropped: PerformException) {
                last = dropped
                if (attempt < attempts - 1) SystemClock.sleep(400L)
            }
        }
        throw requireNotNull(last)
    }
}
