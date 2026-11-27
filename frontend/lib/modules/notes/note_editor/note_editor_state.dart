import 'package:equatable/equatable.dart';
import 'package:jotter/models/jotter_note.dart';

enum EditorStatus { loading, locked, ready, unavailable }

enum SaveStatus { idle, pending, saving, saved, savedOffline, failed }

enum ReadOnlyReason { viewer, permissionLost }

class NoteEditorState extends Equatable {
  const NoteEditorState({
    this.status = EditorStatus.loading,
    this.note,
    this.title = '',
    this.content = '',
    this.isNew = false,
    this.saveStatus = SaveStatus.idle,
    this.saveError,
    this.unlocking = false,
    this.unlockError,
    this.permissionLost = false,
    this.unavailableReason,
    this.newerVersionAvailable = false,
    this.presence = const [],
    this.deleted = false,
  });

  final EditorStatus status;

  /// The last version known to be saved; [title] and [content] are the draft.
  final JotterNote? note;
  final String title;
  final String content;

  /// True until the first autosave creates the note.
  final bool isNew;
  final SaveStatus saveStatus;
  final String? saveError;
  final bool unlocking;
  final String? unlockError;
  final bool permissionLost;
  final String? unavailableReason;
  final bool newerVersionAvailable;
  final List<String> presence;
  final bool deleted;

  bool get canEdit =>
      status == EditorStatus.ready &&
      (note?.canEdit ?? false) &&
      !permissionLost;

  ReadOnlyReason? get readOnlyReason {
    if (note == null || status != EditorStatus.ready) return null;
    if (permissionLost) return ReadOnlyReason.permissionLost;
    return note!.canEdit ? null : ReadOnlyReason.viewer;
  }

  bool get isDirty =>
      note != null && (title != note!.title || content != note!.content);

  bool get hasText => title.trim().isNotEmpty || content.trim().isNotEmpty;

  /// Attachments, sharing and protection need the note to exist on the server.
  bool get existsOnServer => !isNew && (note?.version ?? 0) > 0;

  NoteEditorState copyWith({
    EditorStatus? status,
    JotterNote? note,
    String? title,
    String? content,
    bool? isNew,
    SaveStatus? saveStatus,
    String? saveError,
    bool? unlocking,
    String? unlockError,
    bool? permissionLost,
    String? unavailableReason,
    bool? newerVersionAvailable,
    List<String>? presence,
    bool? deleted,
  }) => NoteEditorState(
    status: status ?? this.status,
    note: note ?? this.note,
    title: title ?? this.title,
    content: content ?? this.content,
    isNew: isNew ?? this.isNew,
    saveStatus: saveStatus ?? this.saveStatus,
    saveError: saveError,
    unlocking: unlocking ?? this.unlocking,
    unlockError: unlockError,
    permissionLost: permissionLost ?? this.permissionLost,
    unavailableReason: unavailableReason ?? this.unavailableReason,
    newerVersionAvailable: newerVersionAvailable ?? this.newerVersionAvailable,
    presence: presence ?? this.presence,
    deleted: deleted ?? this.deleted,
  );

  @override
  List<Object?> get props => [
    status,
    note?.id,
    note?.version,
    note?.isPinned,
    note?.isProtected,
    note?.canEdit,
    note?.labelIds,
    note?.updatedAt,
    title,
    content,
    isNew,
    saveStatus,
    saveError,
    unlocking,
    unlockError,
    permissionLost,
    unavailableReason,
    newerVersionAvailable,
    presence,
    deleted,
  ];
}
