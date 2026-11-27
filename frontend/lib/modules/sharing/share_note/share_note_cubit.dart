import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/modules/sharing/share_note/share_note_api.dart';
import 'package:jotter/modules/sharing/share_note/share_note_state.dart';
import 'package:jotter/shared/lib/api_error.dart';
import 'package:jotter/shared/models/note_permission.dart';

class ShareNoteCubit extends Cubit<ShareNoteState> {
  ShareNoteCubit(this._api, {required this.noteId})
    : super(const ShareNoteState());

  final ShareNoteApi _api;
  final String noteId;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    try {
      final shares = await _api.list(noteId);
      if (!isClosed) emit(state.copyWith(loading: false, shares: shares));
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: _message(error)));
      }
    }
  }

  void setInvitePermission(String email, NotePermission permission) => emit(
    state.copyWith(
      invitePermissions: {
        ...state.invitePermissions,
        email.toLowerCase(): permission,
      },
    ),
  );

  /// Returns the addresses that were not invited, so they can be corrected;
  /// null when the request itself failed.
  Future<List<String>?> invite(List<String> emails) async {
    if (state.busy) return null;
    if (emails.isEmpty) {
      emit(state.copyWith(error: 'Enter at least one email address.'));
      return null;
    }
    emit(state.copyWith(busy: true));
    try {
      final result = await _api.invite(noteId, {
        for (final email in emails) email: state.permissionFor(email),
      });
      final shares = await _api.list(noteId);
      if (isClosed) return null;
      emit(
        state.copyWith(
          busy: false,
          shares: shares,
          notice: result.created == 0 ? null : _invited(result.created),
          error: result.rejected.isEmpty
              ? null
              : [
                  for (final item in result.rejected)
                    '${item.email}: ${apiErrorMessage(item.code) ?? item.code}',
                ].join('\n'),
        ),
      );
      return [for (final item in result.rejected) item.email];
    } catch (error) {
      if (!isClosed) emit(state.copyWith(busy: false, error: _message(error)));
      return null;
    }
  }

  Future<void> changePermission(
    NoteShare share,
    NotePermission permission,
  ) async {
    if (NotePermission.fromApi(share.permission) == permission) return;
    await _run(
      () async {
        await _api.changePermission(noteId, share.id, permission);
        return state.shares
            .map(
              (item) => item.id == share.id
                  ? NoteShare(
                      id: item.id,
                      email: item.email,
                      displayName: item.displayName,
                      permission: permission.apiValue,
                    )
                  : item,
            )
            .toList();
      },
      notice:
          '${_name(share)} ${permission == NotePermission.edit ? 'can now edit' : 'can now only view'}.',
    );
  }

  Future<void> revoke(NoteShare share) => _run(() async {
    await _api.revoke(noteId, share.id);
    return [
      for (final item in state.shares)
        if (item.id != share.id) item,
    ];
  }, notice: '${_name(share)} no longer has access.');

  Future<void> _run(
    Future<List<NoteShare>> Function() action, {
    required String notice,
  }) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      final shares = await action();
      if (!isClosed) {
        emit(state.copyWith(busy: false, shares: shares, notice: notice));
      }
    } catch (error) {
      if (!isClosed) emit(state.copyWith(busy: false, error: _message(error)));
    }
  }

  static String _invited(int count) =>
      count == 1 ? 'Invited 1 person.' : 'Invited $count people.';

  static String _name(NoteShare share) =>
      share.displayName.isEmpty ? share.email : share.displayName;

  static String _message(Object error) => error is RepositoryException
      ? error.message
      : 'Sharing could not be updated. Please try again.';
}
