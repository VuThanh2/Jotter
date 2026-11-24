import 'dart:typed_data';

import 'package:video_player/video_player.dart';

class VideoSource {
  const VideoSource(this.controller, this.release);

  final VideoPlayerController controller;
  final void Function() release;
}

/// Streams the authenticated attachment URL directly.
Future<VideoSource> openVideo({
  required Uri url,
  required Map<String, String> headers,
  required String mimeType,
  required Future<Uint8List> Function() download,
}) async =>
    VideoSource(VideoPlayerController.networkUrl(url, httpHeaders: headers), () {});
