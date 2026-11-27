import 'package:equatable/equatable.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/shared/models/note_permission.dart';

class ShareNoteState extends Equatable {
  const ShareNoteState({
    this.loading = true,
    this.busy = false,
    this.shares = const [],
    this.invitePermissions = const {},
    this.error,
    this.notice,
  });

  final bool loading;
  final bool busy;
  final List<NoteShare> shares;

  /// Chosen per invitee, keyed by lower-case email; unset means view only.
  final Map<String, NotePermission> invitePermissions;
  final String? error;
  final String? notice;

  NotePermission permissionFor(String email) =>
      invitePermissions[email.toLowerCase()] ?? NotePermission.view;

  ShareNoteState copyWith({
    bool? loading,
    bool? busy,
    List<NoteShare>? shares,
    Map<String, NotePermission>? invitePermissions,
    String? error,
    String? notice,
  }) => ShareNoteState(
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    shares: shares ?? this.shares,
    invitePermissions: invitePermissions ?? this.invitePermissions,
    error: error,
    notice: notice,
  );

  @override
  List<Object?> get props => [
    loading,
    busy,
    [for (final share in shares) '${share.id}:${share.permission}'],
    invitePermissions,
    error,
    notice,
  ];
}
