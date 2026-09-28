# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Tauri-react-template: MainActivity.setStatusBarDark(boolean) + the static
# currentActivity field are invoked/read from Rust over JNI
# (`set_status_bar_style` command). Keep the names so release (R8) builds
# don't rename them.
-keepclassmembers class * extends android.app.Activity {
  public void setStatusBarDark(boolean);
  public static * currentActivity;
}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile