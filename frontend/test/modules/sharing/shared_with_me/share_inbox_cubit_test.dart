import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/data/local_workspace_store.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/models/sync_status.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_cubit.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_api.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_store.dart';

import '../../../helpers/fake_api.dart';

class _Notes extends Fake implements NoteStore {
  _Notes(this.current, {DateTime? syncedAt})
    : status = ValueNotifier(WorkspaceSyncStatus(lastSyncedAt: syncedAt));

  List<JotterNote> current;
  final ValueNotifier<WorkspaceSyncStatus> status;
  final _changes = StreamController<List<JotterNote>>.broadcast();
  Map<String, DateTime> sharedAt = {};

  @override
  Map<String, DateTime> get sharedWithMeAt => sharedAt;

  @override
  ValueNotifier<WorkspaceSyncStatus> get syncStatus => status;

  @override
  Stream<List<JotterNote>> watchNotes() async* {
    yield current;
    yield* _changes.stream;
  }

  void sync(List<JotterNote> notes) {
    current = notes;
    status.value = WorkspaceSyncStatus(lastSyncedAt: DateTime(2026, 11, 26));
    _changes.add(notes);
  }
}

class _SharedWithMeApi extends SharedWithMeApi {
  _SharedWithMeApi() : super(fakeApi((_) async => jsonResponse({})));

  @override
  Future<Map<String, SharedNoteInfo>> fetch() async => {
    for (final id in ['a', 'b', 'c'])
      id: SharedNoteInfo(
        noteId: id,
        sharedBy: 'Owner $id',
        sharedAt: DateTime(2026, 11, id.codeUnitAt(0)),
        canEdit: false,
      ),
  };
}

JotterNote _shared(String id) => JotterNote(
  id: id,
  title: 'Note $id',
  content: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  isOwned: false,
);

Future<ShareInboxCubit> _start(_Notes notes, WorkspaceStore storage) async {
  final cubit = ShareInboxCubit(
    notes,
    _SharedWithMeApi(),
    SharedWithMeStore(storage, accountId: 'me'),
  );
  addTearDown(cubit.close);
  await cubit.start();
  await pumpEventQueue();
  return cubit;
}

void main() {
  test('existing shares are not announced on the first run', () async {
    final notes = _Notes([_shared('a')], syncedAt: DateTime(2026));
    final cubit = await _start(notes, MemoryWorkspaceStore());
    expect(cubit.state.latest, isNull);
    expect(cubit.state.unviewed, 0);
  });

  test('a new share is announced with its sharer and counted', () async {
    final notes = _Notes([_shared('a')], syncedAt: DateTime(2026));
    final cubit = await _start(notes, MemoryWorkspaceStore());

    notes.sync([_shared('a'), _shared('b')]);
    await pumpEventQueue();

    expect(cubit.state.latest!.message, 'Owner b shared “Note b” with you.');
    expect(cubit.state.unviewed, 1);
    cubit.markViewed();
    expect(cubit.state.unviewed, 0);
  });

  test(
    'shares that arrived while the app was closed are announced once',
    () async {
      final storage = MemoryWorkspaceStore();
      final first = _Notes([_shared('a')], syncedAt: DateTime(2026));
      await (await _start(first, storage)).close();

      final reopened = _Notes([_shared('a')], syncedAt: DateTime(2026));
      final cubit = await _start(reopened, storage);
      expect(cubit.state.latest, isNull);

      reopened.sync([_shared('a'), _shared('b'), _shared('c')]);
      await pumpEventQueue();
      expect(
        cubit.state.latest!.message,
        'Owner c shared “Note c” and 1 more note with you.',
      );
      expect(cubit.state.unviewed, 2);
    },
  );

  test('a note shared again after a revoke is announced again', () async {
    final notes = _Notes([_shared('a')], syncedAt: DateTime(2026))
      ..sharedAt = {'a': DateTime.utc(2026, 11, 1)};
    final cubit = await _start(notes, MemoryWorkspaceStore());

    notes.sharedAt = {'a': DateTime.utc(2026, 11, 2)};
    notes.sync([_shared('a')]);
    await pumpEventQueue();

    expect(cubit.state.latest!.message, 'Owner a shared “Note a” with you.');
    expect(cubit.state.unviewed, 1);
  });

  test('later syncs of the same share stay quiet', () async {
    final notes = _Notes([_shared('a')], syncedAt: DateTime(2026))
      ..sharedAt = {'a': DateTime.utc(2026, 11, 1)};
    final cubit = await _start(notes, MemoryWorkspaceStore());

    notes.sync([_shared('a')]);
    await pumpEventQueue();
    expect(cubit.state.latest, isNull);
    expect(cubit.state.unviewed, 0);
  });

  test('nothing is announced before the first sync completes', () async {
    final notes = _Notes([]);
    final cubit = await _start(notes, MemoryWorkspaceStore());
    expect(cubit.state.latest, isNull);

    notes.sync([_shared('a')]);
    await pumpEventQueue();
    expect(cubit.state.latest, isNull);
    expect(cubit.state.unviewed, 0);
  });
}
