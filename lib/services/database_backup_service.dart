import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Service สำหรับสำรองและกู้คืนฐานข้อมูล SQLite ทั้งไฟล์
///
/// หมายเหตุ: วิธีนี้ไม่สามารถข้าม Platform ได้ (Android ↔ iOS)
/// เนื่องจากไฟล์ SQLite มีรูปแบบเฉพาะของแต่ละ Platform
class DatabaseBackupService {
  static final DatabaseBackupService instance = DatabaseBackupService._();
  DatabaseBackupService._();

  /// สำรองฐานข้อมูลทั้งไฟล์
  ///
  /// จะคัดลอกไฟล์ money.db และให้ผู้ใช้เลือกตำแหน่งบันทึก
  Future<BackupResult> backupDatabase({required BuildContext context}) async {
    // คำนวณ sharePositionOrigin ก่อน (ต้องเรียกก่อน await เพื่อหลีกเลี่ยง async gap)
    final sharePositionOrigin = _getSharePositionOrigin(context);

    try {
      // หาตำแหน่งไฟล์ฐานข้อมูล
      final dbPath = await getDatabasesPath();
      final dbFilePath = join(dbPath, 'money.db');
      final dbFile = File(dbFilePath);

      // ตรวจสอบว่าไฟล์มีอยู่จริง
      if (!await dbFile.exists()) {
        return BackupResult(success: false, message: 'ไม่พบไฟล์ฐานข้อมูล');
      }

      // อ่านไฟล์ฐานข้อมูล
      final dbBytes = await dbFile.readAsBytes();

      // สร้างไฟล์ชั่วคราวสำหรับแชร์
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFileName = 'money_backup_$timestamp.db';
      final backupFilePath = join(tempDir.path, backupFileName);
      final backupFile = File(backupFilePath);
      await backupFile.writeAsBytes(dbBytes);

      // แชร์ไฟล์
      await Share.shareXFiles(
        [XFile(backupFilePath)],
        subject: 'Money Backup - ${DateTime.now().toString()}',
        sharePositionOrigin: sharePositionOrigin,
      );

      return BackupResult(success: true, message: 'สำรองข้อมูลเรียบร้อยแล้ว');
    } catch (e) {
      debugPrint('BackupDatabase error: $e');
      return BackupResult(success: false, message: 'สำรองข้อมูลไม่สำเร็จ: $e');
    }
  }

  /// คำนวณ sharePositionOrigin สำหรับ iOS
  /// หมายเหตุ: ต้องเรียกก่อน await อื่นๆ เพื่อหลีกเลี่ยง async gap
  Rect? _getSharePositionOrigin(BuildContext context) {
    try {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox) {
        final offset = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;

        // ตรวจสอบว่า size ไม่เป็นศูนย์
        if (size.width > 0 && size.height > 0) {
          return offset & size;
        }
      }
    } catch (e) {
      debugPrint('Error getting sharePositionOrigin: $e');
    }

    // ส่งคืน null ถ้าไม่สามารถคำนวณได้ (จะใช้ค่า default ของระบบ)
    return null;
  }

  /// กู้คืนฐานข้อมูลจากไฟล์
  ///
  /// ให้ผู้ใช้เลือกไฟล์ .db และเขียนทับไฟล์ฐานข้อมูลเดิม
  Future<RestoreResult> restoreDatabase({required BuildContext context}) async {
    // ให้ผู้ใช้เลือกไฟล์สำรอง
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result == null || result.files.single.path == null) {
      return RestoreResult(
        success: false,
        canceled: true,
        message: 'ยกเลิกการกู้คืน',
      );
    }

    final backupFilePath = result.files.single.path!;
    final backupFile = File(backupFilePath);

    if (!await backupFile.exists()) {
      return RestoreResult(success: false, message: 'ไม่พบไฟล์สำรอง');
    }

    // แสดง Dialog ยืนยัน (ก่อนใช้ context ที่อาจข้าม async gap)
    if (!context.mounted) {
      return RestoreResult(success: false, message: 'Context not mounted');
    }

    final confirmed = await _showRestoreConfirmation(context);
    if (!confirmed) {
      return RestoreResult(
        success: false,
        canceled: true,
        message: 'ยกเลิกการกู้คืน',
      );
    }

    if (!context.mounted) {
      return RestoreResult(success: false, message: 'Context not mounted');
    }

    try {
      // อ่านไฟล์สำรอง
      final backupBytes = await backupFile.readAsBytes();

      // หาตำแหน่งไฟล์ฐานข้อมูลเดิม
      final dbPath = await getDatabasesPath();
      final dbFilePath = join(dbPath, 'money.db');
      final dbFile = File(dbFilePath);

      // เขียนทับไฟล์ฐานข้อมูลเดิม
      await dbFile.writeAsBytes(backupBytes);

      return RestoreResult(success: true, message: 'กู้คืนข้อมูลเรียบร้อยแล้ว');
    } catch (e) {
      return RestoreResult(
        success: false,
        message: 'กู้คืนข้อมูลไม่สำเร็จ: $e',
      );
    }
  }

  Future<bool> _showRestoreConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ยืนยันการกู้คืนข้อมูล'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('คุณต้องการกู้คืนข้อมูลจากไฟล์สำรองหรือไม่?'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ คำเตือน:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• ข้อมูลปัจจุบันจะถูกแทนที่ด้วยข้อมูลจากไฟล์สำรอง\n'
                        '• การกระทำนี้ไม่สามารถย้อนกลับได้\n'
                        '• ควรสำรองข้อมูลปัจจุบันก่อนกู้คืน',
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('กู้คืน'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// ผลลัพธ์จากการสำรองข้อมูล
class BackupResult {
  final bool success;
  final String message;

  BackupResult({required this.success, required this.message});
}

/// ผลลัพธ์จากการกู้คืนข้อมูล
class RestoreResult {
  final bool success;
  final bool canceled;
  final String message;

  RestoreResult({
    required this.success,
    this.canceled = false,
    required this.message,
  });
}
