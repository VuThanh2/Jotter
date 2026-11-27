import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/models/sync_status.dart';
import 'package:jotter/modules/labels/label_management/label_management_page.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/modules/profile/shared/me_api.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';

class _Labels extends Fake implements LabelStore {
  _Labels(this._current);

  List<JotterLabel> _current;
  final _changes = StreamController<List<JotterLabel>>.broadcast();
  final status = ValueNotifier(const WorkspaceSyncStatus());
  int refreshes = 0;

  @override
  List<JotterLabel> get labels => _current;
  @override
  ValueNotifier<WorkspaceSyncStatus> get syncStatus => status;
  @override
  Stream<List<JotterLabel>> watchLabels() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  int noteCount(String labelId) => 0;
  @override
  Future<void> refresh() async {
    refreshes++;
    _current = const [JotterLabel(id: 'l1', name: 'Work')];
    _changes.add(_current);
    status.value = WorkspaceSyncStatus(lastSyncedAt: DateTime(2026));
  }
}

Future<void> _pump(WidgetTester tester, LabelStore labels) async {
  final remote = ApiNoteRepository.fromSession(
    baseUrl: 'https://example.test',
    session: {
      'accessToken': 'test',
      'user': {
        'userId': '1',
        'email': 'a@example.test',
        'displayName': 'A',
        'isActivated': true,
      },
    },
  );
  final me = MeCubit(MeApi(remote), onAccountChanged: () {});
  addTearDown(() async {
    await me.close();
    remote.dispose();
  });
  await tester.pumpWidget(
    RepositoryProvider<LabelStore>.value(
      value: labels,
      child: BlocProvider<MeCubit>.value(
        value: me,
        child: const MaterialApp(home: LabelManagementPage()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a first load while offline offers retry, not "No labels"', (
    tester,
  ) async {
    final labels = _Labels(const [])
      ..status.value = const WorkspaceSyncStatus(isOffline: true);
    await _pump(tester, labels);
    expect(find.textContaining('could not be loaded while offline'), findsOne);
    expect(find.text('No labels yet'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(labels.refreshes, 1);
    expect(find.text('Work'), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsNothing);
  });

  testWidgets('shows loading until the first sync, then the empty state', (
    tester,
  ) async {
    final labels = _Labels(const [])
      ..status.value = const WorkspaceSyncStatus(isSyncing: true);
    await _pump(tester, labels);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.text('No labels yet'), findsNothing);

    labels.status.value = WorkspaceSyncStatus(lastSyncedAt: DateTime(2026));
    await tester.pump();
    expect(find.text('No labels yet'), findsOneWidget);
  });

  testWidgets('cached labels show even when the latest sync failed', (
    tester,
  ) async {
    final labels = _Labels(const [JotterLabel(id: 'l1', name: 'Travel')])
      ..status.value = const WorkspaceSyncStatus(isOffline: true);
    await _pump(tester, labels);
    expect(find.text('Travel'), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsNothing);
  });
}
