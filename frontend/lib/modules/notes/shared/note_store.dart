import 'package:flutter/foundation.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/data/sync_api.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/models/sync_status.dart';

/// Notes as cached by the offline workspace. Writes are queued while offline.
class NoteStore {
  NoteStore(this._workspace);

  final OfflineNoteRepository _workspace;
  final List<String> _watching = [];

  String get accountId => _workspace.remote.account.id;
  List<JotterNote> get notes => _workspace.cachedNotes;
  ValueListenable<WorkspaceSyncStatus> get syncStatus => _workspace.syncStatus;
  Stream<Map<String, dynamic>> get noteEvents => _workspace.realtimeEvents;
  Map<String, DateTime> get sharedWithMeAt => _workspace.sharedWithMeAt;

  Stream<List<JotterNote>> watchNotes() async* {
    yield notes;
    yield* _workspace.changes.map((_) => notes);
  }

  JotterNote? cached(String id) => _workspace.cachedNote(id);

  /// An offline edit of this note was rejected because it changed elsewhere.
  bool hasConflict(String noteId) => _workspace.pendingChanges.any(
    (change) => change.noteId == noteId && change.isConflict,
  );

  Future<void> refresh() => _workspace.synchronize();

  Future<List<JotterNote>> search(String query) =>
      _workspace.listNotes(query: query);

  Future<JotterNote> open(String id) => _workspace.getNote(id);

  Future<JotterNote> unlock(String id, String password) =>
      _workspace.unlockNote(id, password);

  Future<JotterNote> save(JotterNote note, {required bool isNew}) =>
      _workspace.saveNote(note, isNew: isNew);

  Future<JotterNote> setPinned(JotterNote note, bool pinned) =>
      _workspace.pinNote(note, pinned);

  Future<JotterNote> setLabels(JotterNote note, List<String> labelIds) =>
      _workspace.setLabels(note, labelIds);

  Future<void> delete(String id) => _workspace.deleteNote(id);

  Future<int> latestVersion(String id) => _workspace.remote.getNoteVersion(id);

  /// Joins the note's realtime channel so presence and edits arrive live.
  Future<void> watch(String noteId) {
    _watching.add(noteId);
    return _workspace.watchNote(noteId);
  }

  /// Editors overlap while one route replaces another, so closing the old one
  /// must not leave the note the new one has just joined.
  Future<void> unwatch(String noteId) {
    _watching.remove(noteId);
    return _workspace.watchNote(_watching.lastOrNull);
  }
}
