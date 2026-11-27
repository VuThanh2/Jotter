import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jotter/shared/lib/file_service.dart';

class _Picker extends ImagePicker {
  _Picker({this.error});

  final PlatformException? error;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (error != null) throw error!;
    return null;
  }
}

void main() {
  test('a denied camera explains how to allow it', () {
    final files = FileService(
      picker: _Picker(error: PlatformException(code: 'camera_access_denied')),
    );
    expect(
      files.pickImage(PickSource.camera),
      throwsA(
        isA<PickPermissionDenied>().having(
          (error) => error.message,
          'message',
          contains('Settings › Apps › Jotter › Permissions'),
        ),
      ),
    );
  });

  test('cancelling the picker is not an error', () async {
    final files = FileService(picker: _Picker());
    expect(await files.pickImage(PickSource.camera), isNull);
  });
}
