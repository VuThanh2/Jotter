import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/api_note_repository.dart';

http.Response jsonResponse(Object? value, [int status = 200]) => http.Response(
  value == null ? '' : jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

/// A signed-in API client whose every request goes to [handler].
ApiNoteRepository fakeApi(
  Future<http.Response> Function(http.Request request) handler,
) => ApiNoteRepository.fromSession(
  baseUrl: 'http://localhost:5080',
  session: {
    'accessToken': 'test-token',
    'user': {
      'userId': 'owner',
      'email': 'owner@example.com',
      'displayName': 'Owner',
      'isActivated': true,
    },
  },
  client: MockClient(handler),
);

/// Pumps a screen of [size] with [api] available, then taps a button that
/// runs [open] — the way dialogs are opened in the app.
Future<void> openWithApi(
  WidgetTester tester,
  ApiNoteRepository api,
  Future<void> Function(BuildContext context) open, {
  Size size = const Size(1000, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepositoryProvider.value(
      value: api,
      child: MaterialApp(
        theme: jotterTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
