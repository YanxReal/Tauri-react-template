package {{escape-kotlin-keyword app.identifier}}

import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat

class MainActivity : TauriActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)
    applyStatusBarContrast("onCreate")
  }

  override fun onResume() {
    super.onResume()
    // The user can flip system dark mode while the app runs; re-apply so the
    // status-bar icons stay visible (light icons on dark, dark icons on light).
    applyStatusBarContrast("onResume")
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    // The activity declares uiMode in android:configChanges, so a system
    // dark/light flip does NOT recreate it (and onResume does NOT fire).
    // Without this, the flags go stale: dark system icons stay stuck over a
    // dark WebView and the clock/signal/battery "disappear".
    applyStatusBarContrast("onConfigurationChanged")
  }

  override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    // Most reliable point: the window is attached and focused. Anything the
    // WebView setup resets (system bars appearance) gets re-applied here.
    if (hasFocus) {
      applyStatusBarContrast("onWindowFocusChanged")
    }
  }

  private fun applyStatusBarContrast(caller: String) {
    val night =
      resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
        Configuration.UI_MODE_NIGHT_YES
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
