import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/notes/note_editor/note_editor_bloc.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';

class _Notes extends Fake implements NoteStore {
  _Notes([this.saved]);

  final JotterNote? saved;

  @override
  JotterNote? cached(String id) => saved?.id == id ? saved : null;

  @override
  Future<void> unwatch(String noteId) async {}
}

void main() {
  final saved = JotterNote(
    id: 'n',
    title: 'Trip',
    content: 'Lake',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('a new note link starts blank until the note exists', () async {
    final bloc = NoteEditorBloc(_Notes(), noteId: 'n', isNew: true);
    addTearDown(bloc.close);
    expect(bloc.startsBlank, isTrue);
  });

  test('reopening a new note link after saving loads the note', () async {
    final bloc = NoteEditorBloc(_Notes(saved), noteId: 'n', isNew: true);
    addTearDown(bloc.close);
    expect(bloc.startsBlank, isFalse);
  });
}
