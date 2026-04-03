import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Future<void> saveCsvFiles(
  Map<String, String> files, {
  Rect? sharePositionOrigin,
}) async {
  for (final entry in files.entries) {
    final bytes = Uint8List.fromList(utf8.encode(entry.value));
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = entry.key
      ..style.display = 'none';

    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);

    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<String?> readPlatformFileAsString(PlatformFile file) async {
  final bytes = file.bytes;
  if (bytes == null) {
    return null;
  }

  return utf8.decode(bytes);
}
