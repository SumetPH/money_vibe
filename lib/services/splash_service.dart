import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/material.dart';

/// Service สำหรับจัดการ Splash Screen
/// ใช้ร่วมกับ flutter_native_splash package
class SplashService {
  /// เรียกเมื่อเริ่มต้นโหลดข้อมูล
  static WidgetsBinding initialize() {
    // เก็บ reference ของ WidgetsBinding เพื่อป้องกัน splash screen ถูก remove ก่อนเวลา
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    return widgetsBinding;
  }

  /// เรียกเมื่อโหลดข้อมูลเสร็จสิ้น เพื่อ remove splash screen
  static void remove() {
    FlutterNativeSplash.remove();
  }
}
