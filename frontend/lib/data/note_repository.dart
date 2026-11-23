import '../models/jotter_label.dart';
import '../models/jotter_note.dart';
import 'note_ids.dart';

String generateUuid() => newNoteId();

const defaultApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:5080',
);

abstract class NoteRepository {
  bool get isPreview;
  Future<List<JotterNote>> listNotes({String? query});
  Future<JotterNote> getNote(String id);
  Future<List<JotterLabel>> listLabels();
  Future<JotterNote> saveNote(JotterNote note, {bool isNew = false});
  Future<JotterNote> pinNote(JotterNote note, bool pinned);
  Future<void> deleteNote(String id);
  Future<JotterLabel> createLabel(String name);
  Future<JotterLabel> renameLabel(String id, String name) =>
      throw const RepositoryException('Label renaming is unavailable.');
  Future<void> deleteLabel(String id) =>
      throw const RepositoryException('Label deletion is unavailable.');
  Future<JotterNote> setLabels(JotterNote note, List<String> ids);
  Future<JotterNote> unlockNote(String id, String password);
  Future<void> close();
}

class RepositoryException implements Exception {
  const RepositoryException(
    this.message, {
    this.code,
    this.statusCode,
    this.details = const {},
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic> details;

  @override
  String toString() => message;
}

void validateNote(JotterNote note) {
  if (note.title.trim().isEmpty && note.content.trim().isEmpty) {
    throw const RepositoryException(
      'Add a title or some content before saving.',
    );
  }
  if (note.title.length > 200) {
    throw const RepositoryException(
      'Keep your note title under 200 characters.',
    );
  }
  if (note.content.length > 50000) {
    throw const RepositoryException(
      'A note can contain up to 50,000 characters.',
    );
  }
}
