import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ตัวกรองยอดเงินสุทธิเวอร์ชันเก่าที่เคยเก็บใน SharedPreferences
/// (ตอนนี้เก็บใน accounts.is_excluded_from_net_worth_filter แล้ว)
/// ใช้อ่านค่าเดิมครั้งเดียวเพื่อย้ายขึ้น database แล้วลบทิ้ง
class LegacyNetWorthFilterStore {
  static const _key = 'net_worth_filter_ids';

  const LegacyNetWorthFilterStore._();

  /// คืน id ของบัญชีที่เคยเลือกไว้; null = ไม่มีค่าเก่าค้างอยู่
  static Future<Set<String>?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json == null) return null;
      final decoded = jsonDecode(json);
      if (decoded is! List) return null;
      return decoded.whereType<String>().toSet();
    } catch (e) {
      debugPrint('LegacyNetWorthFilterStore: failed to read: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
