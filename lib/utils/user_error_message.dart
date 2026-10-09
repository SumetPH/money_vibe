import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final _thaiCharacters = RegExp(r'[฀-๿]');

/// แปลง exception เป็นข้อความที่แสดงให้ผู้ใช้ได้ โดยไม่เปิดเผยรายละเอียดภายใน
/// (SQL, stack, URL) และ log ค่าเต็มไว้ด้วย debugPrint
///
/// [action] คือสิ่งที่กำลังทำ เช่น `'บันทึก'` → "บันทึกไม่สำเร็จ กรุณาลองใหม่"
String userErrorMessage(Object error, {required String action}) {
  debugPrint('userErrorMessage($action): $error');

  // ข้อความ validation ที่แอปเขียนเป็นภาษาไทยเอง แสดงต่อได้เลย
  final appMessage = _appAuthoredMessage(error);
  if (appMessage != null) return appMessage;

  if (_isNetworkError(error)) {
    return '$actionไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต';
  }
  if (error is AuthException) {
    return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่';
  }
  return '$actionไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
}

String? _appAuthoredMessage(Object error) {
  final message = switch (error) {
    ArgumentError(:final message) when message is String => message,
    StateError(:final message) => message,
    FormatException(:final message) => message,
    _ => null,
  };
  if (message == null || !_thaiCharacters.hasMatch(message)) return null;
  return message;
}

bool _isNetworkError(Object error) {
  // ไม่ import dart:io เพื่อให้ใช้บน web ได้ จึงเช็ค SocketException จากชื่อ type
  return error is TimeoutException ||
      error is http.ClientException ||
      error.runtimeType.toString() == 'SocketException';
}
