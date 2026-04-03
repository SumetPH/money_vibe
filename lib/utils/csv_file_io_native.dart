import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveCsvFiles(
  Map<String, String> files, {
  Rect? sharePositionOrigin,
}) async {
  final tempDir = await getTemporaryDirectory();
  final xFiles = <XFile>[];

  for (final entry in files.entries) {
    final file = File('${tempDir.path}/${entry.key}');
    await file.writeAsString(entry.value, encoding: utf8);
    xFiles.add(XFile(file.path));
  }

  await Share.shareXFiles(
    xFiles,
    subject: 'Money App Backup ${DateTime.now().toString().split('.')[0]}',
    sharePositionOrigin: sharePositionOrigin,
  );
}

Future<String?> readPlatformFileAsString(PlatformFile file) async {
  if (file.bytes != null) {
    return utf8.decode(file.bytes!);
  }

  final path = file.path;
  if (path == null) {
    return null;
  }

  return File(path).readAsString(encoding: utf8);
}
