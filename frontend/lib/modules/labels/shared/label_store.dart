import 'package:flutter/foundation.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/models/sync_status.dart';

class LabelStore {
  LabelStore(this._workspace);

  final OfflineNoteRepository _workspace;

  List<JotterLabel> get labels => _sorted(_workspace.cachedLabels);

  /// Labels arrive with workspace sync, so its status is their load status.
  ValueListenable<WorkspaceSyncStatus> get syncStatus => _workspace.syncStatus;

  Future<void> refresh() => _workspace.synchronize();

  Stream<List<JotterLabel>> watchLabels() async* {
    yield labels;
    yield* _workspace.changes.map((_) => labels);
  }

  int noteCount(String labelId) => _workspace.cachedNotes
      .where((note) => note.labelIds.contains(labelId))
      .length;

  Future<JotterLabel> create(String name) => _workspace.createLabel(name);

  Future<JotterLabel> rename(String id, String name) =>
      _workspace.renameLabel(id, name);

  Future<void> delete(String id) => _workspace.deleteLabel(id);

  static List<JotterLabel> _sorted(List<JotterLabel> labels) =>
      [...labels]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
