import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/data/account_api.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/jotter_account.dart';
import 'package:jotter/models/jotter_preferences.dart';
import 'package:jotter/widgets/account_dialog.dart';
import 'package:jotter/widgets/account_settings_dialog.dart';

Map<String, dynamic> profile({bool activated = false}) => {
  'userId': 'user-1',
  'email': 'reader@jotter.app',
  'displayName': 'Reader',
  'isActivated': activated,
  'avatarUrl': null,
};
ApiNoteRepository repository(http.Client client, {bool activated = false}) =>
    ApiNoteRepository.fromSession(
      baseUrl: 'http://localhost:5080',
      session: {
        'accessToken': 'old-token',
        'user': profile(activated: activated),
      },
      client: client,
    );
http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'registration submits confirmation and returns its own inactive session',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.url.path, '/api/auth/register');
        expect(jsonDecode(request.body), {
          'email': 'reader@jotter.app',
          'displayName': 'Reader',
          'password': 'Strong@123',
          'confirmPassword': 'Strong@123',
        });
        return jsonResponse({
          'accessToken': 'registration-token',
          'user': profile(),
        }, 201);
      });
      final api = AccountAuthApi('http://localhost:5080/', client: client);
      final result = await api.register(
        email: ' reader@jotter.app ',
        displayName: ' Reader ',
        password: 'Strong@123',
        confirmPassword: 'Strong@123',
      );
      expect(result.account.id, 'user-1');
      expect(result.account.isActivated, isFalse);
      expect(requests, hasLength(1));
      api.close();
    },
  );

  test(
    'reset verifies email and code then submits ticket without email or code',
    () async {
      final requests = <http.Request>[];
      final api = AccountAuthApi(
        'http://localhost:5080',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/forgot')) {
            expect(jsonDecode(request.body), {'email': 'reader@jotter.app'});
            return http.Response('', 202);
          }
          if (request.url.path.endsWith('/verify-code')) {
            expect(jsonDecode(request.body), {
              'email': 'reader@jotter.app',
              'code': '123456',
            });
            return jsonResponse({
              'resetTicket': 'one-use-ticket',
              'expiresAt': '2026-10-28T14:00:00Z',
            });
          }
          expect(request.url.path, '/api/auth/password/reset');
          expect(jsonDecode(request.body), {
            'resetTicket': 'one-use-ticket',
            'newPassword': 'New@1234',
            'confirmPassword': 'New@1234',
          });
          return http.Response('', 204);
        }),
      );
      await api.forgotPassword('reader@jotter.app');
      final ticket = await api.verifyResetCode('reader@jotter.app', '123456');
      await api.resetPassword(ticket, 'New@1234', 'New@1234');
      expect(requests, hasLength(3));
      api.close();
    },
  );

  test(
    'anonymous validation errors expose field messages and stable server code',
    () async {
      final api = AccountAuthApi(
        'http://localhost:5080',
        client: MockClient(
          (_) async => jsonResponse({
            'code': 'ValidationError',
            'title': 'Invalid data',
            'errors': {
              'password': [
                {
                  'code': 'PasswordTooShort',
                  'message': 'Choose a longer password.',
                },
              ],
            },
          }, 400),
        ),
      );
      await expectLater(
        api.register(
          email: 'reader@jotter.app',
          displayName: 'Reader',
          password: 'x',
          confirmPassword: 'x',
        ),
        throwsA(
          isA<RepositoryException>()
              .having(
                (error) => error.message,
                'message',
                'Choose a longer password.',
              )
              .having((error) => error.code, 'code', 'ValidationError'),
        ),
      );
      api.close();
    },
  );

  test(
    'activation replaces access token before the next authenticated call',
    () async {
      var confirms = 0;
      final repo = repository(
        MockClient((request) async {
          if (request.url.path.endsWith('/activation/confirm')) {
            confirms++;
            expect(request.headers['authorization'], 'Bearer old-token');
            expect(jsonDecode(request.body), {'code': '123456'});
            return jsonResponse({
              'isActivated': true,
              'accessToken': 'activated-token',
              'expiresAt': '2026-10-28T14:00:00Z',
            });
          }
          expect(request.url.path, '/api/me');
          expect(request.headers['authorization'], 'Bearer activated-token');
          return jsonResponse(profile(activated: true));
        }),
      );
      await repo.confirmActivation('123456');
      expect(repo.account.isActivated, isTrue);
      await repo.getProfile();
      expect(confirms, 1);
    },
  );

  test(
    'password change uses current password and immediately rotates bearer',
    () async {
      final repo = repository(
        MockClient((request) async {
          if (request.url.path.endsWith('/password/change')) {
            expect(jsonDecode(request.body), {
              'currentPassword': 'Old@1234',
              'newPassword': 'New@1234',
              'confirmPassword': 'New@1234',
            });
            return jsonResponse({'accessToken': 'changed-token'});
          }
          expect(request.headers['authorization'], 'Bearer changed-token');
          return jsonResponse(profile());
        }),
      );
      await repo.changePassword('Old@1234', 'New@1234', 'New@1234');
      await repo.getProfile();
    },
  );

  test('preferences round trip all fields and profile rename updates active account', () async {
    const preferences = JotterPreferences(
      noteFontSize: 22,
      defaultNoteColor: '#EAF0E6',
      themeMode: 'Dark',
      listViewMode: 'List',
    );
    final repo = repository(
      MockClient((request) async {
        if (request.url.path.endsWith('/preferences')) {
          if (request.method == 'PUT') {
            expect(jsonDecode(request.body), preferences.toJson());
          }
          return jsonResponse(preferences.toJson());
        }
        expect(request.method, 'PUT');
        expect(jsonDecode(request.body), {'displayName': 'New Reader'});
        return jsonResponse({...profile(), 'displayName': 'New Reader'});
      }),
    );
    expect((await repo.getPreferences()).toJson(), preferences.toJson());
    expect(
      (await repo.updatePreferences(preferences)).toJson(),
      preferences.toJson(),
    );
    await repo.updateProfile(' New Reader ');
    expect(repo.account.displayName, 'New Reader');
  });

  test(
    'avatar fetch stays authenticated and removing clears profile metadata',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final repo = repository(
        MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer old-token');
          if (request.method == 'GET') {
            expect(request.url.path, '/api/users/user-1/avatar');
            expect(request.url.queryParameters['v'], 'new-photo');
            return http.Response.bytes(bytes, 200);
          }
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/me/avatar');
          return http.Response('', 204);
        }),
      );
      repo.account = repo.account.copyWith(
        avatarUrl: '/api/users/user-1/avatar?v=new-photo',
      );
      expect(await repo.getAvatar(), bytes);
      await repo.removeAvatar();
      expect(repo.account.avatarUrl, isNull);
    },
  );

  test(
    'account model preserves activation and can explicitly clear avatar',
    () {
      final account = JotterAccount.fromJson({
        ...profile(),
        'avatarUrl': '/avatar',
      });
      expect(account.copyWith(displayName: 'Updated').isActivated, isFalse);
      expect(account.copyWith(clearAvatar: true).avatarUrl, isNull);
      expect(
        JotterPreferences.fromJson(const {}).toJson(),
        const JotterPreferences().toJson(),
      );
    },
  );

  testWidgets(
    'registration and recovery controls are reachable on a narrow phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAccountDialog(context),
                child: const Text('Open account'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create an account'));
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-name')), findsOneWidget);
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your display name.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Back to sign in'));
      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Send reset code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preferences apply only after the server confirms a save', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var savedCount = 0;
    JotterPreferences? applied;
    final repo = repository(
      MockClient((request) async {
        expect(request.url.path, '/api/me/preferences');
        savedCount++;
        if (savedCount == 1) {
          return jsonResponse({'title': 'Preferences unavailable.'}, 503);
        }
        return jsonResponse(jsonDecode(request.body));
      }),
      activated: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAccountSettingsDialog(
                context,
                repository: repo,
                preferences: const JotterPreferences(),
                onPreferencesChanged: (value) => applied = value,
              ),
              child: const Text('Settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('default-note-color')),
      '#ABCDEF',
    );
    await tester.ensureVisible(find.text('Save preferences'));
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(applied, isNull);
    expect(find.text('Preferences unavailable.'), findsOneWidget);
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(applied!.defaultNoteColor, '#ABCDEF');
    expect(savedCount, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'settings preserve failed profile input and validate password confirmation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = repository(
        MockClient(
          (request) async => jsonResponse({
            'code': 'Unavailable',
            'title': 'Please try again.',
          }, 503),
        ),
        activated: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAccountSettingsDialog(
                  context,
                  repository: repo,
                  preferences: const JotterPreferences(),
                  onPreferencesChanged: (_) {},
                ),
                child: const Text('Settings'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'Unsaved Reader',
      );
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(find.text('Please try again.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('profile-name')))
            .controller!
            .text,
        'Unsaved Reader',
      );
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('current-password')),
        'Old@1234',
      );
      await tester.enterText(find.byKey(const Key('new-password')), 'New@1234');
      await tester.enterText(
        find.byKey(const Key('confirm-new-password')),
        'Different',
      );
      await tester.ensureVisible(find.text('Change password'));
      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
