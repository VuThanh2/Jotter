import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum PickSource { gallery, camera, cameraVideo, files }

class PickPermissionDenied implements Exception {
  const PickPermissionDenied(this.source);

  final PickSource source;

  String get message => switch (source) {
    PickSource.camera || PickSource.cameraVideo =>
      'Jotter needs camera access. Allow it in your device settings '
          '(Settings › Apps › Jotter › Permissions), then try again.',
    _ =>
      'Jotter needs access to your photos. Allow it in your device settings '
          '(Settings › Apps › Jotter › Permissions), then try again.',
  };

  @override
  String toString() => message;
}

/// Picks files from the gallery, camera or file browser. Cancelling returns an empty result.
class FileService {
  FileService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  bool get supportsCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// The gallery only differs from the file browser on phones.
  bool get supportsGallery => supportsCamera;

  Future<List<XFile>> pickMany(PickSource source) => _guard(source, () async {
    switch (source) {
      case PickSource.gallery:
        return _picker.pickMultipleMedia();
      case PickSource.camera:
        final photo = await _picker.pickImage(source: ImageSource.camera);
        return [?photo];
      case PickSource.cameraVideo:
        final video = await _picker.pickVideo(source: ImageSource.camera);
        return [?video];
      case PickSource.files:
        return selector.openFiles();
    }
  });

  Future<XFile?> pickImage(PickSource source) async {
    final files = await _guard(source, () async {
      switch (source) {
        case PickSource.gallery:
          return [?await _picker.pickImage(source: ImageSource.gallery)];
        case PickSource.camera || PickSource.cameraVideo:
          return [?await _picker.pickImage(source: ImageSource.camera)];
        case PickSource.files:
          return [
            ?await selector.openFile(
              acceptedTypeGroups: const [
                selector.XTypeGroup(
                  label: 'Images',
                  extensions: ['jpg', 'jpeg', 'png', 'webp'],
                  mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
                ),
              ],
            ),
          ];
      }
    });
    return files.firstOrNull;
  }

  Future<List<XFile>> _guard(
    PickSource source,
    Future<List<XFile>> Function() pick,
  ) async {
    try {
      return await pick();
    } on PlatformException catch (error) {
      if (error.code.contains('denied') || error.code.contains('permission')) {
        throw PickPermissionDenied(source);
      }
      rethrow;
    }
  }
}
