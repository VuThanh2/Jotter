import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_features_api.dart';
import 'package:jotter/models/note_features.dart';

class AskAiApi {
  AskAiApi(this._remote);

  final ApiNoteRepository _remote;

  Future<NotesAnswer> ask(String question) => _remote.askNotes(question);
}
