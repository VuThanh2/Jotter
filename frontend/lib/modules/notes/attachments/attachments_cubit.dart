import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jotter/data/note_features_api.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/modules/notes/attachments/attachments_api.dart';
import 'package:jotter/modules/notes/attachments/attachments_state.dart';
import 'package:jotter/shared/lib/file_service.dart';

class AttachmentsCubit extends Cubit<AttachmentsState> {
  AttachmentsCubit(this._api, this._files, {required this.noteId})
    : super(const AttachmentsState());

  final AttachmentsApi _api;
  final FileService _files;
  final String noteId;

  bool get supportsCamera => _files.supportsCamera;
  bool get supportsGallery => _files.supportsGallery;

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: state.error));
    try {
      final files = await _api.list(noteId);
      if (!isClosed) emit(state.copyWith(files: files, loading: false));
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: _message(error)));
      }
    }
  }

  Future<void> pickAndUpload(PickSource source) async {
    final List<XFile> picked;
    try {
      picked = await _files.pickMany(source);
    } on PickPermissionDenied catch (error) {
      emit(state.copyWith(error: error.message));
      return;
    }
    if (picked.isNotEmpty) await upload(picked);
  }

  /// Uploads one request per file so each one reports its own outcome.
  Future<void> upload(List<XFile> files) async {
    var uploads = [
      ...state.uploads.where((item) => item.status != UploadStatus.done),
      for (final file in files) UploadItem(file.name),
    ];
    emit(state.copyWith(uploads: uploads));
    for (final file in files) {
      UploadItem result;
      try {
        if (await file.length() > maxAttachmentBytes) {
          throw const RepositoryException('Larger than the 25 MB limit.');
        }
        await _api.upload(noteId, await file.readAsBytes(), file.name);
        result = UploadItem(file.name, status: UploadStatus.done);
      } catch (error) {
        result = UploadItem(
          file.name,
          status: UploadStatus.failed,
          error: _message(error),
        );
      }
      if (isClosed) return;
      uploads = [
        for (final item in uploads)
          item.name == file.name && item.status == UploadStatus.uploading
              ? result
              : item,
      ];
      emit(state.copyWith(uploads: uploads));
    }
    await load();
    if (!isClosed) {
      emit(
        state.copyWith(
          uploads: [
            for (final item in state.uploads)
              if (item.status == UploadStatus.failed) item,
          ],
        ),
      );
    }
  }

  void dismissUpload(UploadItem item) =>
      emit(state.copyWith(uploads: [...state.uploads]..remove(item)));

  Future<void> remove(String attachmentId) async {
    try {
      await _api.remove(attachmentId);
      if (!isClosed) {
        emit(
          state.copyWith(
            files: [
              for (final file in state.files)
                if (file.id != attachmentId) file,
            ],
          ),
        );
      }
    } catch (error) {
      if (!isClosed) emit(state.copyWith(error: _message(error)));
    }
  }

  static String _message(Object error) => error is RepositoryException
      ? error.message
      : 'The file could not be processed.';
}
