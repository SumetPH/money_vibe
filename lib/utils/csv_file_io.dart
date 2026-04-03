import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'csv_file_io_stub.dart'
    if (dart.library.io) 'csv_file_io_native.dart'
    if (dart.library.html) 'csv_file_io_web.dart'
    as impl;

Future<void> saveCsvFiles(
  Map<String, String> files, {
  Rect? sharePositionOrigin,
}) {
  return impl.saveCsvFiles(files, sharePositionOrigin: sharePositionOrigin);
}

Future<String?> readPlatformFileAsString(PlatformFile file) {
  return impl.readPlatformFileAsString(file);
}
