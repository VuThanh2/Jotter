import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_features_api.dart';
import 'package:jotter/models/note_features.dart';

class SummaryApi {
  SummaryApi(this._remote);

  final ApiNoteRepository _remote;

  /// Null when the note has never been summarized.
  Future<NoteSummary?> saved(String noteId) => _remote.getSummary(noteId);

  Stream<SummaryEvent> generate(String noteId) =>
      _remote.generateSummary(noteId);
}
