import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/modules/notes/attachments/attachments_api.dart';
import 'package:jotter/platform/file_transfer.dart';
import 'package:jotter/shared/lib/video_source.dart';

class AttachmentViewerState extends Equatable {
  const AttachmentViewerState({
    this.file,
    this.bytes,
    this.video,
    this.loading = true,
    this.error,
    this.notice,
  });

  final NoteAttachment? file;
  final Uint8List? bytes;
  final VideoSource? video;
  final bool loading;
  final String? error;
  final String? notice;

  AttachmentViewerState copyWith({
    NoteAttachment? file,
    Uint8List? bytes,
    VideoSource? video,
    bool? loading,
    String? error,
    String? notice,
  }) => AttachmentViewerState(
    file: file ?? this.file,
    bytes: bytes ?? this.bytes,
    video: video ?? this.video,
    loading: loading ?? this.loading,
    error: error,
    notice: notice,
  );

  @override
  List<Object?> get props => [file?.id, bytes, video, loading, error, notice];
}

class AttachmentViewerCubit extends Cubit<AttachmentViewerState> {
  AttachmentViewerCubit(
    this._api, {
    required this.noteId,
    required this.attachmentId,
    NoteAttachment? file,
  }) : super(AttachmentViewerState(file: file));

  final AttachmentsApi _api;
  final String noteId;
  final String attachmentId;

  Future<void> load() async {
    try {
      final file =
          state.file ??
          (await _api.list(
            noteId,
          )).firstWhere((item) => item.id == attachmentId);
      emit(state.copyWith(file: file));
      if (file.isVideo) {
        final video = await openVideo(
          url: _api.contentUri(file.id),
          headers: _api.authHeaders,
          mimeType: file.mimeType,
          download: () => _api.download(file.id),
        );
        await video.controller.initialize();
        if (isClosed) {
          await video.controller.dispose();
          video.release();
          return;
        }
        emit(state.copyWith(video: video, loading: false));
      } else if (file.isImage) {
        final bytes = await _api.download(file.id);
        emit(state.copyWith(bytes: bytes, loading: false));
      } else {
        emit(state.copyWith(loading: false));
      }
    } on StateError {
      emit(state.copyWith(loading: false, error: 'This file no longer exists.'));
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          error: error is RepositoryException
              ? error.message
              : 'This file cannot be shown here. You can still download it.',
        ),
      );
    }
  }

  Future<void> download() async {
    final file = state.file;
    if (file == null) return;
    try {
      final bytes = state.bytes ?? await _api.download(file.id);
      await saveBytes(bytes, file.name, mimeType: file.mimeType);
      if (!isClosed) emit(state.copyWith(notice: 'Downloaded ${file.name}.'));
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            error: error is RepositoryException
                ? error.message
                : 'The download did not finish.',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    final video = state.video;
    if (video != null) {
      await video.controller.dispose();
      video.release();
    }
    return super.close();
  }
}
