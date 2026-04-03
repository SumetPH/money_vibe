import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

Future<void> saveCsvFiles(
  Map<String, String> files, {
  Rect? sharePositionOrigin,
}) async {
  throw UnsupportedError('CSV export is not supported on this platform');
}

Future<String?> readPlatformFileAsString(PlatformFile file) async {
  throw UnsupportedError('CSV import is not supported on this platform');
}
