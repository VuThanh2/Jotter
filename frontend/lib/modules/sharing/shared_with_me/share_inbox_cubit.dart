import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_state.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_api.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_store.dart';

/// Notices notes newly shared with this account as they arrive through sync,
/// including ones shared while the app was closed.
class ShareInboxCubit extends Cubit<ShareInboxState> {
  ShareInboxCubit(this._notes, this._api, this._store)
    : super(const ShareInboxState());

  final NoteStore _notes;
  final SharedWithMeApi _api;
  final SharedWithMeStore _store;
  StreamSubscription<List<JotterNote>>? _subscription;
  ShareMarks? _marks;

  /// Shared notes by share, so a note shared again after a revoke is new.
  Map<String, JotterNote> _shared = const {};

  Future<void> start() async {
    _marks = await _store.read();
    if (isClosed) return;
    _subscription = _notes.watchNotes().listen(_notesChanged);
  }

  /// The user is looking at the Shared tab.
  void markViewed() {
    final marks = _marks;
    if (marks == null || state.unviewed == 0) return;
    _remember(
      ShareMarks(
        announced: marks.announced,
        viewed: {...marks.viewed, ..._shared.keys},
      ),
    );
    emit(ShareInboxState(latest: state.latest));
  }

  Future<void> _notesChanged(List<JotterNote> notes) async {
    final sharedAt = _notes.sharedWithMeAt;
    _shared = {
      for (final note in notes)
        if (!note.isOwned) _shareKey(note.id, sharedAt[note.id]): note,
    };
    final marks = _marks ?? _firstMarks();
    if (marks == null) return;
    final fresh = [
      for (final key in _shared.keys)
        if (!marks.announced.contains(key)) key,
    ];
    final updated = fresh.isEmpty
        ? marks
        : ShareMarks(
            announced: {...marks.announced, ...fresh},
            viewed: marks.viewed,
          );
    if (!identical(updated, _marks)) _remember(updated);
    final unviewed = _shared.keys.where((key) => !updated.viewed.contains(key));
    emit(ShareInboxState(unviewed: unviewed.length, latest: state.latest));
    if (fresh.isNotEmpty) {
      await _announce([for (final key in fresh) _shared[key]!], sharedAt);
    }
  }

  static String _shareKey(String noteId, DateTime? sharedAt) => sharedAt == null
      ? noteId
      : '$noteId@${sharedAt.toUtc().toIso8601String()}';

  /// On a first run everything already shared counts as known, but only after
  /// a sync: before that the list may be incomplete.
  ShareMarks? _firstMarks() {
    if (_notes.syncStatus.value.lastSyncedAt == null) return null;
    final keys = _shared.keys.toSet();
    return ShareMarks(announced: keys, viewed: keys);
  }

  Future<void> _announce(
    List<JotterNote> notes,
    Map<String, DateTime> sharedAt,
  ) async {
    var note = notes.first;
    var sharedBy = '';
    try {
      final info = await _api.fetch();
      final newest = notes.where((item) => info.containsKey(item.id)).toList()
        ..sort((a, b) => info[b.id]!.sharedAt.compareTo(info[a.id]!.sharedAt));
      if (newest.isNotEmpty) {
        note = newest.first;
        sharedBy = info[note.id]!.sharedBy;
      }
    } catch (_) {
      // The notice still goes out, just without the sharer's name.
    }
    if (isClosed) return;
    emit(
      ShareInboxState(
        unviewed: state.unviewed,
        latest: ShareAnnouncement(
          noteId: note.id,
          title: note.title,
          sharedBy: sharedBy,
          sharedAt: sharedAt[note.id],
          others: notes.length - 1,
        ),
      ),
    );
  }

  void _remember(ShareMarks marks) {
    _marks = marks;
    unawaited(_store.write(marks));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
