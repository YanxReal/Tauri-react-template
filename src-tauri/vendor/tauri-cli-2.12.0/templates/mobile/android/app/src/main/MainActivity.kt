package {{escape-kotlin-keyword app.identifier}}

import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat

class MainActivity : TauriActivity() {
  companion object {
    /**
     * The currently resumed activity, for Rust to find over JNI
     * (`set_status_bar_style` command). Set in onResume; the command treats a
     * null as "no activity yet" and degrades gracefully. Kept by name for JNI
     * (see proguard-rules.pro).
     */
    @JvmStatic
    var currentActivity: MainActivity? = null

    /**
     * Last status-bar style requested by the FRONTEND (its resolved theme),
     * persisted across backgrounding. `onResume`/`onWindowFocusChanged`/
     * `onConfigurationChanged` re-apply THIS, not the system night state —
     * otherwise a light app on a dark system (or vice versa) gets invisible
     * icons every time the user returns from the background.
     */
    @JvmStatic
    var lastJsNight: Boolean? = null
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)
    applyStatusBarContrast(resolvedNight(), "onCreate")
  }

  override fun onResume() {
    super.onResume()
    currentActivity = this
    // Returning from the background: re-apply the LAST app-resolved style
    // (the system may reset the bars appearance while the app is away). The
    // frontend keeps its theme, so the icons must keep their contrast.
    applyStatusBarContrast(resolvedNight(), "onResume")
  }

  override fun onPause() {
    if (currentActivity === this) {
      currentActivity = null
    }
    super.onPause()
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    // The activity declares uiMode in android:configChanges, so a system
    // dark/light flip does NOT recreate it (and onResume does NOT fire).
    // Without this, the flags go stale: dark system icons stay stuck over a
    // dark WebView and the clock/signal/battery "disappear".
    applyStatusBarContrast(resolvedNight(), "onConfigurationChanged")
  }

  override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    // Most reliable point: the window is attached and focused. Anything the
    // WebView setup resets (system bars appearance) gets re-applied here.
    if (hasFocus) {
      applyStatusBarContrast(resolvedNight(), "onWindowFocusChanged")
    }
  }

  /**
   * Called from Rust (`set_status_bar_style` command) with the frontend's
   * RESOLVED theme. Needed because the app has its own theme override
   * (toggle/D key/localStorage): the user can run a light app on a dark
   * system (or vice versa), and the system-following flags alone would then
   * paint invisible icons. Runs on the UI thread internally, so the Rust
   * caller thread doesn't matter. Kept by name for JNI (see proguard-rules.pro).
   */
  fun setStatusBarDark(isDark: Boolean) {
    lastJsNight = isDark
    runOnUiThread { applyStatusBarContrast(isDark, "js") }
  }

  private fun isSystemNight(): Boolean =
    resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
      Configuration.UI_MODE_NIGHT_YES

  /** The app's resolved night state: the frontend's choice when known, the
   *  system's otherwise (before the first JS call). */
  private fun resolvedNight(): Boolean = lastJsNight ?: isSystemNight()

  private fun applyStatusBarContrast(night: Boolean, caller: String) {
    val view = window.decorView
    val controller = WindowCompat.getInsetsController(window, view)
    // Light status-bar icons on dark backgrounds, dark icons on light ones.
    // Without this, edge-to-edge leaves dark system icons invisible over a
    // dark WebView (the clock/signal/battery "disappear" in dark mode).
    controller.isAppearanceLightStatusBars = !night
    controller.isAppearanceLightNavigationBars = !night
    Log.d("TauriStatusBar", "$caller: night=$night lightBars=${!night}")
  }
}
