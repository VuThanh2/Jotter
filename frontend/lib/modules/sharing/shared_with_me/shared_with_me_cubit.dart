import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_api.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_state.dart';

class SharedWithMeCubit extends Cubit<SharedWithMeState> {
  SharedWithMeCubit(this._store, this._api) : super(const SharedWithMeState()) {
    _subscription = _store.watchNotes().listen(_notesChanged);
    refresh();
  }

  final NoteStore _store;
  final SharedWithMeApi _api;
  late final StreamSubscription<List<JotterNote>> _subscription;
  bool _refreshing = false;

  Future<void> refresh() async {
    if (_refreshing || isClosed) return;
    _refreshing = true;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _store.refresh();
      final info = await _api.fetch();
      final sync = _store.syncStatus.value;
      final refreshFailed =
          sync.isOffline || (sync.error != null && sync.conflictCount == 0);
      if (!isClosed) {
        emit(
          state.copyWith(
            info: info,
            loading: false,
            error: refreshFailed
                ? 'Shared notes could not be refreshed. Check your connection and try again.'
                : null,
            clearError: !refreshFailed,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            loading: false,
            error: 'Shared notes could not be refreshed. Check your connection and try again.',
          ),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  void _notesChanged(List<JotterNote> notes) {
    if (isClosed) return;
    final shared = notes.where((note) => !note.isOwned).toList();
    final known = state.info.keys.toSet();
    emit(state.copyWith(notes: shared));
    // A new share appeared through sync: fetch who shared it.
    if (!_refreshing && shared.any((note) => !known.contains(note.id))) {
      unawaited(refresh());
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
