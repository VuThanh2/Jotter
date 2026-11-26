import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/modules/notes/notes_home/notes_home_state.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/shared/lib/config.dart';
import 'package:jotter/shared/lib/debouncer.dart';

class NotesHomeCubit extends Cubit<NotesHomeState> {
  NotesHomeCubit(this._notes, this._labels) : super(const NotesHomeState()) {
    _subscriptions = [
      _notes.watchNotes().listen(_notesChanged),
      _labels.watchLabels().listen(
        (labels) => emit(state.copyWith(labels: labels, error: state.error)),
      ),
    ];
    refresh();
  }

  final NoteStore _notes;
  final LabelStore _labels;
  final _searchDebounce = Debouncer(AppConfig.searchDebounce);
  late final List<StreamSubscription<Object?>> _subscriptions;
  int _searchGeneration = 0;

  Future<void> refresh() async {
    if (state.refreshing || isClosed) return;
    emit(state.copyWith(refreshing: true, error: state.error));
    try {
      await _notes.refresh();
      if (isClosed) return;
      final sync = _notes.syncStatus.value;
      if (sync.isOffline || (sync.error != null && sync.conflictCount == 0)) {
        emit(
          state.copyWith(
            status: _notes.notes.isEmpty
                ? NotesStatus.failure
                : NotesStatus.ready,
            refreshing: false,
            error: sync.isOffline
                ? 'Your notes could not be refreshed while offline. Check your connection and try again.'
                : 'Your notes could not be refreshed. Please try again.',
          ),
        );
      } else {
        emit(state.copyWith(status: NotesStatus.ready, refreshing: false));
      }
    } catch (error) {
      if (isClosed) return;
      // With a local cache the list still works; only an empty first load fails.
      emit(
        state.notes.isEmpty
            ? state.copyWith(
                status: NotesStatus.failure,
                refreshing: false,
                error: _message(error),
              )
            : state.copyWith(
                status: NotesStatus.ready,
                refreshing: false,
                error: _message(error),
              ),
      );
    }
  }

  void search(String query) {
    // Invalidates any in-flight search so a slow, older reply cannot win.
    _searchGeneration++;
    if (query.trim().isEmpty) {
      _searchDebounce.cancel();
      emit(
        state.copyWith(
          query: query,
          clearSearchResults: true,
          searching: false,
        ),
      );
      return;
    }
    // Previous results stay visible during the debounce, so the list does not
    // flash "Nothing matches" on every keystroke; a first search shows loading.
    emit(state.copyWith(query: query, searching: true));
    _searchDebounce.run(_runSearch);
  }

  void retrySearch() {
    if (state.isSearching) _runSearch();
  }

  void toggleLabel(String labelId) {
    final selected = {...state.selectedLabelIds};
    if (!selected.remove(labelId)) selected.add(labelId);
    emit(state.copyWith(selectedLabelIds: selected));
  }

  void clearLabels() => emit(state.copyWith(selectedLabelIds: const {}));

  /// Returns an error message to show, or null on success.
  Future<String?> togglePin(JotterNote note) =>
      _attempt(() => _notes.setPinned(note, !note.isPinned));

  Future<String?> setLabels(JotterNote note, List<String> labelIds) =>
      _attempt(() => _notes.setLabels(note, labelIds));

  Future<String?> delete(JotterNote note) =>
      _attempt(() => _notes.delete(note.id));

  void _notesChanged(List<JotterNote> notes) {
    if (isClosed) return;
    final status = notes.isNotEmpty ? NotesStatus.ready : state.status;
    emit(state.copyWith(notes: notes, status: status, error: state.error));
    if (state.isSearching) _runSearch(silent: true);
  }

  Future<void> _runSearch({bool silent = false}) async {
    final generation = ++_searchGeneration;
    final query = state.query.trim();
    if (!silent) emit(state.copyWith(searching: true));
    try {
      final results = await _notes.search(query);
      if (isClosed || generation != _searchGeneration) return;
      emit(state.copyWith(searchResults: results, searching: false));
    } catch (error) {
      if (isClosed || generation != _searchGeneration) return;
      emit(state.copyWith(searching: false, error: _message(error)));
    }
  }

  Future<String?> _attempt(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (error) {
      return _message(error);
    }
  }

  static String _message(Object error) => error is RepositoryException
      ? error.message
      : 'Something went wrong. Please try again.';

  @override
  Future<void> close() {
    _searchDebounce.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    return super.close();
  }
}
