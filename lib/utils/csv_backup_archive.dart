import 'dart:typed_data';

import 'package:archive/archive.dart';

/// รวมไฟล์เพื่อให้เว็บดาวน์โหลดครั้งเดียว ไม่ติดข้อจำกัดการดาวน์โหลดหลายไฟล์
Uint8List encodeCsvBackup(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}
