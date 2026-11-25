import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/modules/notes/attachments/attachment_viewer_cubit.dart';
import 'package:jotter/modules/notes/attachments/attachments_api.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/shared/widgets/state_views.dart';
import 'package:video_player/video_player.dart';

class AttachmentViewerPage extends StatelessWidget {
  const AttachmentViewerPage({
    super.key,
    required this.noteId,
    required this.attachmentId,
    this.file,
  });

  final String noteId;
  final String attachmentId;
  final NoteAttachment? file;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => AttachmentViewerCubit(
      AttachmentsApi(context.read<ApiNoteRepository>()),
      noteId: noteId,
      attachmentId: attachmentId,
      file: file,
    )..load(),
    child: BlocConsumer<AttachmentViewerCubit, AttachmentViewerState>(
      listenWhen: (_, state) => state.notice != null,
      listener: (context, state) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.notice!))),
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(state.file?.name ?? 'Attachment'),
          leading: BackButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.note(noteId)),
          ),
          actions: [
            const UnverifiedBanner(compact: true),
            IconButton(
              key: const Key('download-attachment'),
              tooltip: 'Download',
              onPressed: state.file == null
                  ? null
                  : context.read<AttachmentViewerCubit>().download,
              icon: const Icon(Icons.download_rounded),
            ),
          ],
        ),
        body: SafeArea(child: _body(context, state)),
      ),
    ),
  );

  Widget _body(BuildContext context, AttachmentViewerState state) {
    if (state.loading) return const LoadingView(label: 'Loading file');
    final video = state.video;
    if (video != null) return _VideoView(controller: video.controller);
    final bytes = state.bytes;
    if (bytes != null) {
      return InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.memory(
            bytes,
            errorBuilder: (_, _, _) => const ErrorView(
              message: 'This image cannot be shown. You can still download it.',
            ),
          ),
        ),
      );
    }
    return EmptyView(
      icon: Icons.insert_drive_file_outlined,
      title: state.file?.name ?? 'File',
      message:
          state.error ??
          'This kind of file opens in another app. Download it to view it.',
      action: FilledButton.icon(
        onPressed: state.file == null
            ? null
            : context.read<AttachmentViewerCubit>().download,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Download'),
      ),
    );
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController get _video => widget.controller;

  void _toggle() =>
      setState(() => _video.value.isPlaying ? _video.pause() : _video.play());

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: _video.value.aspectRatio,
            child: GestureDetector(onTap: _toggle, child: VideoPlayer(_video)),
          ),
        ),
      ),
      VideoProgressIndicator(_video, allowScrubbing: true),
      ValueListenableBuilder(
        valueListenable: _video,
        builder: (context, value, _) => IconButton(
          tooltip: value.isPlaying ? 'Pause' : 'Play',
          iconSize: 36,
          onPressed: _toggle,
          icon: Icon(
            value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
      ),
    ],
  );
}
