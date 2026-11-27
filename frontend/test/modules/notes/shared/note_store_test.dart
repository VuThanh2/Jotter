import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';

class _Workspace extends Fake implements OfflineNoteRepository {
  String? watched;

  @override
  Future<void> watchNote(String? noteId) async => watched = noteId;
}

void main() {
  test('closing the previous editor keeps the next note joined', () async {
    final workspace = _Workspace();
    final store = NoteStore(workspace);

    await store.watch('a');
    await store.watch('b');
    await store.unwatch('a');
    expect(workspace.watched, 'b');

    await store.unwatch('b');
    expect(workspace.watched, isNull);
  });

  test('reopening the same note stays joined until both close', () async {
    final workspace = _Workspace();
    final store = NoteStore(workspace);

    await store.watch('a');
    await store.watch('a');
    await store.unwatch('a');
    expect(workspace.watched, 'a');

    await store.unwatch('a');
    expect(workspace.watched, isNull);
  });
}
