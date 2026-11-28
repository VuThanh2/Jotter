import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/data/account_api.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/jotter_account.dart';
import 'package:jotter/models/jotter_preferences.dart';

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
    'validation errors are shown in English with the stable server code',
    () async {
      final api = AccountAuthApi(
        'http://localhost:5080',
        client: MockClient(
          (_) async => jsonResponse({
            'code': 'DisplayNameRequired',
            'title': 'Tên hiển thị không được để trống.',
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
                'Enter your display name.',
              )
              .having((error) => error.code, 'code', 'DisplayNameRequired'),
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
}
