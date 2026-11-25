import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/models/jotter_label.dart';

class LabelStore {
  LabelStore(this._workspace);

  final OfflineNoteRepository _workspace;

  List<JotterLabel> get labels => _sorted(_workspace.cachedLabels);

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
