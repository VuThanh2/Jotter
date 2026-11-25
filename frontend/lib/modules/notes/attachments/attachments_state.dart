import 'package:equatable/equatable.dart';
import 'package:jotter/models/note_features.dart';

enum UploadStatus { uploading, done, failed }

class UploadItem extends Equatable {
  const UploadItem(this.name, {this.status = UploadStatus.uploading, this.error});

  final String name;
  final UploadStatus status;
  final String? error;

  @override
  List<Object?> get props => [name, status, error];
}

class AttachmentsState extends Equatable {
  const AttachmentsState({
    this.files = const [],
    this.loading = true,
    this.uploads = const [],
    this.error,
  });

  final List<NoteAttachment> files;
  final bool loading;
  final List<UploadItem> uploads;
  final String? error;

  bool get uploading =>
      uploads.any((upload) => upload.status == UploadStatus.uploading);

  AttachmentsState copyWith({
    List<NoteAttachment>? files,
    bool? loading,
    List<UploadItem>? uploads,
    String? error,
  }) => AttachmentsState(
    files: files ?? this.files,
    loading: loading ?? this.loading,
    uploads: uploads ?? this.uploads,
    error: error,
  );

  @override
  List<Object?> get props => [
    [for (final file in files) file.id],
    loading,
    uploads,
    error,
  ];
}
