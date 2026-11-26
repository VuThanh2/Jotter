import 'package:flutter/material.dart';
import 'package:jotter/shared/lib/file_service.dart';

/// Lets phones choose between gallery, camera and files.
Future<PickSource?> showAttachmentSourceSheet(
  BuildContext context, {
  required bool supportsCamera,
  required bool supportsGallery,
}) => showModalBottomSheet<PickSource>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (supportsGallery)
          const _Source(
            PickSource.gallery,
            Icons.photo_library_outlined,
            'Photos and videos',
          ),
        if (supportsCamera) ...const [
          _Source(
            PickSource.camera,
            Icons.photo_camera_outlined,
            'Take a photo',
          ),
          _Source(
            PickSource.cameraVideo,
            Icons.videocam_outlined,
            'Record a video',
          ),
        ],
        const _Source(PickSource.files, Icons.attach_file_rounded, 'Files'),
      ],
    ),
  ),
);

class _Source extends StatelessWidget {
  const _Source(this.source, this.icon, this.label);

  final PickSource source;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    onTap: () => Navigator.pop(context, source),
  );
}
