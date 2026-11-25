import 'dart:js_interop';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

class VideoSource {
  const VideoSource(this.controller, this.release);

  final VideoPlayerController controller;
  final void Function() release;
}

/// Browsers cannot attach a bearer token to `<video>`, so the bytes are
/// downloaded first and played from a blob URL.
Future<VideoSource> openVideo({
  required Uri url,
  required Map<String, String> headers,
  required String mimeType,
  required Future<Uint8List> Function() download,
}) async {
  final bytes = await download();
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final blobUrl = web.URL.createObjectURL(blob);
  return VideoSource(
    VideoPlayerController.networkUrl(Uri.parse(blobUrl)),
    () => web.URL.revokeObjectURL(blobUrl),
  );
}
