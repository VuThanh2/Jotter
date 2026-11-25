import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/local_workspace_store.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/profile/preferences/preferences_store.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_page.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required bool cached,
    bool failSync = false,
  }) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var failShares = !failSync;
    final remote = ApiNoteRepository.fromSession(
      baseUrl: 'https://example.test',
      session: {
        'accessToken': 'test',
        'user': {
          'userId': 'owner',
          'email': 'owner@example.test',
          'displayName': 'Owner',
          'isActivated': true,
        },
      },
      client: MockClient((request) async {
        if (request.url.path == '/api/sync' && failSync) {
          failSync = false;
          return http.Response(jsonEncode({'title': 'Unavailable'}), 503);
        }
        if (request.url.path == '/api/shared-with-me') {
          if (failShares) {
            failShares = false;
            return http.Response(jsonEncode({'title': 'Unavailable'}), 503);
          }
          return http.Response(
            jsonEncode({'items': [], 'nextCursor': null}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'notes': cached
                ? [
                    {
                      'noteId': 'shared',
                      'ownerId': 'other',
                      'title': 'Shared note',
                      'content': 'hello',
                      'isProtected': false,
                      'permission': 'ReadOnly',
                      'version': 1,
                      'changeSeq': 1,
                      'createdAt': '2026-01-01T00:00:00Z',
                      'updatedAt': '2026-01-01T00:00:00Z',
                      'deletedAt': null,
                    },
                  ]
                : [],
            'labels': [],
            'shares': [],
            'attachments': [],
            'nextChangeSeq': 1,
            'hasMore': false,
            'fullResyncRequired': false,
          }),
          200,
        );
      }),
    );
    final workspace = await OfflineNoteRepository.open(
      remote,
      store: MemoryWorkspaceStore(),
      startBackground: false,
      enableRealtime: false,
    );
    if (cached) await workspace.synchronize();
    final preferences = PreferencesCubit(PreferencesStore());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await preferences.close();
      workspace.dispose();
    });
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<NoteStore>.value(value: NoteStore(workspace)),
          RepositoryProvider<ApiNoteRepository>.value(value: remote),
        ],
        child: BlocProvider.value(
          value: preferences,
          child: const MaterialApp(home: SharedWithMePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows error instead of empty results and retries successfully', (
    tester,
  ) async {
    await mount(tester, cached: false);
    expect(find.text('Something got in the way'), findsOneWidget);
    expect(find.text('Nothing shared with you yet'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing shared with you yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps cached notes visible alongside an error and retry', (
    tester,
  ) async {
    await mount(tester, cached: true);
    expect(find.text('Shared note'), findsOneWidget);
    expect(find.textContaining('could not be refreshed'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Shared note'), findsOneWidget);
    expect(find.textContaining('could not be refreshed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a sync failure even when shared metadata loads', (
    tester,
  ) async {
    await mount(tester, cached: false, failSync: true);
    expect(find.text('Something got in the way'), findsOneWidget);
    expect(find.text('Nothing shared with you yet'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing shared with you yet'), findsOneWidget);
  });
}
