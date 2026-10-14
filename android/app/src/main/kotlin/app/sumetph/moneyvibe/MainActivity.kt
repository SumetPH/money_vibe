package app.sumetph.moneyvibe

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "money_vibe/app_icon")
            .setMethodCallHandler { call, result ->
                if (call.method != "setDarkIcon") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val isDark = call.arguments as? Boolean ?: true
                setDarkIcon(isDark)
                setSplashTheme(isDark)
                result.success(null)
            }
    }

    // Android 13+ จำ splash theme ไว้ใช้ตอน cold start ครั้งถัดไป (ต่ำกว่านั้นตามระบบ)
    private fun setSplashTheme(isDark: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        splashScreen.setSplashScreenTheme(
            if (isDark) R.style.SplashThemeDark else R.style.SplashThemeLight,
        )
    }

    // สลับ launcher icon ด้วยการเปิด/ปิด activity-alias (LauncherDark เปิดเป็นค่าเริ่มต้นใน manifest)
    private fun setDarkIcon(isDark: Boolean) {
        val dark = ComponentName(this, "app.sumetph.moneyvibe.LauncherDark")
        val light = ComponentName(this, "app.sumetph.moneyvibe.LauncherLight")
        val darkState = packageManager.getComponentEnabledSetting(dark)
        val isDarkActive = darkState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
            darkState == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
        if (isDarkActive == isDark) return

        val (enable, disable) = if (isDark) dark to light else light to dark
        // เปิดตัวใหม่ก่อนปิดตัวเก่า กันช่วงที่ไม่มี launcher entry เลย
        packageManager.setComponentEnabledSetting(
            enable,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        packageManager.setComponentEnabledSetting(
            disable,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}
