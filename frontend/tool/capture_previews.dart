// Local review rendering only. Every request is handled by MockClient.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/preview_note_repository.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/models/jotter_preferences.dart';
import 'package:jotter/screens/workspace_screen.dart';
import 'package:jotter/theme.dart';
import 'package:jotter/widgets/account_settings_dialog.dart';
import 'package:jotter/widgets/ask_notes_dialog.dart';
import 'package:jotter/widgets/note_details_dialog.dart';

const _reviewAccount = {
  'userId': 'review-user',
  'email': 'alex@jotter.test',
  'displayName': 'Alex Morgan',
  'isActivated': true,
  'avatarUrl': null,
};

http.Response _json(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
);

ApiNoteRepository _mockRepository() => ApiNoteRepository.fromSession(
  baseUrl: 'http://jotter.test',
  session: {'accessToken': 'review-token', 'user': _reviewAccount},
  client: MockClient((request) async {
    switch ((request.method, request.url.path)) {
      case ('GET', '/api/me'):
        return _json(_reviewAccount);
      case ('GET', '/api/me/preferences'):
        return _json(const JotterPreferences().toJson());
      case ('GET', '/api/notes/review-note/shares'):
        return _json({
          'items': [
            {
              'shareId': 'share-maya',
              'recipientEmail': 'maya@jotter.test',
              'recipientDisplayName': 'Maya Chen',
              'permission': 'Edit',
            },
            {
              'shareId': 'share-noah',
              'recipientEmail': 'noah@jotter.test',
              'recipientDisplayName': 'Noah Ellis',
              'permission': 'ReadOnly',
            },
          ],
        });
      case ('POST', '/api/ai/ask'):
        return _json({
          'answer': 'Bring the two welcome-screen directions, a short brand story, and the latest team feedback. Leave time to explain the decisions behind each direction before choosing the next step.',
          'hasEnoughContext': true,
          'citations': [
            {
              'noteId': 'review-note',
              'title': 'Studio review plan',
              'excerpt': 'Prepare two welcome-screen directions. Gather feedback from the team before Thursday.',
            },
            {
              'noteId': 'brand-note',
              'title': 'The brand, in a few words',
              'excerpt': 'Lead with the value. Use real words and keep the explanation simple.',
            },
          ],
        });
      case ('POST', '/api/auth/logout'):
        return http.Response('', 204);
      default:
        throw StateError(
          'Unexpected review request: ${request.method} ${request.url.path}',
        );
    }
  }),
);

ThemeData _reviewTheme(ThemeData base) => base.copyWith(
  textTheme: base.textTheme.apply(fontFamily: 'JotterReview'),
  primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'JotterReview'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Future<void> load(String family, String path) async {
      final bytes = await File(path).readAsBytes();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }

    await load('JotterReview', 'C:/Windows/Fonts/segoeui.ttf');
    await load(
      'MaterialIcons',
      'C:/Users/lepha/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
  });

  Future<GlobalKey> mount(
    WidgetTester tester,
    Size size,
    Widget home, {
    bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _reviewTheme(jotterTheme),
          darkTheme: _reviewTheme(jotterDarkTheme),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  Widget launch(Future<void> Function(BuildContext) open) => Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => open(context),
          child: const Text('Open review'),
        ),
      ),
    ),
  );

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await Directory('build/previews')
          .create(recursive: true);
      await File('${directory.path}/$name.png').writeAsBytes(
        png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  }

  testWidgets('render account settings review', (tester) async {
    final repository = _mockRepository();
    addTearDown(repository.dispose);
    final key = await mount(
      tester,
      const Size(800, 900),
      launch((context) async {
        await showAccountSettingsDialog(
          context,
          repository: repository,
          preferences: const JotterPreferences(),
          onPreferencesChanged: (_) {},
        );
      }),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    await capture(tester, key, 'account-settings');
  });

  testWidgets('render sharing at phone width', (tester) async {
    final repository = _mockRepository();
    addTearDown(repository.dispose);
    final now = DateTime.utc(2026, 10, 28, 9);
    final note = JotterNote(
      id: 'review-note',
      title: 'Studio review plan',
      content: 'Two welcome-screen directions and room for feedback.',
      createdAt: now,
      updatedAt: now,
      version: 3,
    );
    final key = await mount(
      tester,
      const Size(390, 844),
      launch((context) async {
        await showNoteDetailsDialog(
          context,
          repository: repository,
          note: note,
          initialTab: 'Sharing',
        );
      }),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    expect(find.text('Maya Chen'), findsOneWidget);
    await tester.ensureVisible(find.text('Maya Chen'));
    await tester.pumpAndSettle();
    await capture(tester, key, 'sharing-phone');
  });

  testWidgets('render an AI answer with citations', (tester) async {
    final repository = _mockRepository();
    addTearDown(repository.dispose);
    final key = await mount(
      tester,
      const Size(960, 1000),
      launch((context) async {
        await showAskNotesDialog(
          context,
          repository: repository,
          onOpenNote: (_) async {},
        );
      }),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ask-notes-question')),
      'How should I prepare for the studio review?',
    );
    await tester.tap(find.byKey(const Key('ask-notes-submit')));
    await tester.pumpAndSettle();
    expect(find.text('From your notes'), findsOneWidget);
    await tester.ensureVisible(find.text('Studio review plan'));
    await tester.pumpAndSettle();
    await capture(tester, key, 'ask-notes');
  });

  testWidgets('render dark notes workspace', (tester) async {
    final key = await mount(
      tester,
      const Size(1440, 1000),
      WorkspaceScreen(
        repository: PreviewNoteRepository(),
        preferences: const JotterPreferences(themeMode: 'Dark'),
      ),
      dark: true,
    );
    await capture(tester, key, 'workspace-dark');
  });
}
