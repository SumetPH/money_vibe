import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'csv_backup_archive.dart';

Future<void> saveCsvFiles(
  Map<String, String> files, {
  Rect? sharePositionOrigin,
}) async {
  if (files.isEmpty) return;
  final bytes = encodeCsvBackup(files);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download =
        'money_vibe_backup_${DateTime.now().millisecondsSinceEpoch}.zip'
    ..style.display = 'none';

  web.document.body?.append(anchor);
  try {
    anchor.click();
    // ให้ browser เริ่มอ่าน Blob ก่อนคืน URL
    await Future<void>.delayed(const Duration(seconds: 1));
  } finally {
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }
}

Future<String?> readPlatformFileAsString(PlatformFile file) async {
  final bytes = file.bytes;
  if (bytes == null) {
    return null;
  }

  return utf8.decode(bytes);
}
