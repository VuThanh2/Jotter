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

  Future<void> refresh() async {
    try {
      await _store.refresh();
      final info = await _api.fetch();
      if (!isClosed) emit(state.copyWith(info: info, loading: false));
    } catch (_) {
      // Offline: cached notes still show, just without sharer details.
      if (!isClosed) emit(state.copyWith(loading: false));
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  void _notesChanged(List<JotterNote> notes) {
    if (isClosed) return;
    final shared = notes.where((note) => !note.isOwned).toList();
    final known = state.info.keys.toSet();
    emit(state.copyWith(notes: shared));
    // A new share appeared through sync: fetch who shared it.
    if (shared.any((note) => !known.contains(note.id))) {
      unawaited(_refreshInfo());
    }
  }

  Future<void> _refreshInfo() async {
    try {
      final info = await _api.fetch();
      if (!isClosed) emit(state.copyWith(info: info));
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
