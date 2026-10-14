import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// สลับ launcher icon (และ splash บน Android 13+) ให้ตรงกับ dark mode ในแอป (ไม่ใช่ของระบบ)
/// Android ใช้ activity-alias + setSplashScreenTheme, iOS ใช้ alternate icon
/// (ระบบจะเด้ง alert ทุกครั้งที่เปลี่ยน; splash iOS ตามระบบเสมอ)
class AppIconService {
  AppIconService._();

  static const _channel = MethodChannel('money_vibe/app_icon');

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> apply({required bool isDarkMode}) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('setDarkIcon', isDarkMode);
    } on PlatformException catch (e) {
      debugPrint('AppIconService: failed to switch icon: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('AppIconService: channel unavailable: $e');
    }
  }
}
