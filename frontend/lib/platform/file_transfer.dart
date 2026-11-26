import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

/// Saves authenticated bytes through the browser or the platform's save dialog.
Future<bool> saveBytes(
  Uint8List bytes,
  String filename, {
  String? mimeType,
}) async {
  final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
  final result = await FileSaver.instance.saveAs(
    name: safeName.isEmpty ? 'download' : safeName,
    bytes: bytes,
    includeExtension: false,
    mimeType: MimeType.custom,
    customMimeType: mimeType ?? 'application/octet-stream',
    dialogTitle: 'Save from Jotter',
  );
  return kIsWeb || result != null;
}
