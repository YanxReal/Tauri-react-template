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
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)
    applyStatusBarContrast(isSystemNight(), "onCreate")
  }

  override fun onResume() {
    super.onResume()
    currentActivity = this
    // The user can flip system dark mode while the app runs; re-apply so the
    // status-bar icons stay visible (light icons on dark, dark icons on light).
    applyStatusBarContrast(isSystemNight(), "onResume")
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
    applyStatusBarContrast(isSystemNight(), "onConfigurationChanged")
  }

  override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    // Most reliable point: the window is attached and focused. Anything the
    // WebView setup resets (system bars appearance) gets re-applied here.
    if (hasFocus) {
      applyStatusBarContrast(isSystemNight(), "onWindowFocusChanged")
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
    runOnUiThread { applyStatusBarContrast(isDark, "js") }
  }

  private fun isSystemNight(): Boolean =
    resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
      Configuration.UI_MODE_NIGHT_YES

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
