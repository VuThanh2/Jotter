import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/jotter_account.dart';
import '../models/jotter_preferences.dart';
import 'api_note_repository.dart';
import 'note_repository.dart';

/// Anonymous account lifecycle endpoints. Authenticated operations use the active repository.
class AccountAuthApi {
  AccountAuthApi(String baseUrl, {http.Client? client})
    : _client = client ?? http.Client(),
      _baseUrl = _validateUrl(baseUrl);
  final String _baseUrl;
  final http.Client _client;

  static String _validateUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const RepositoryException(
        'Enter a valid HTTP or HTTPS server URL.',
      );
    }
    return uri.toString().replaceFirst(RegExp(r'/+$'), '');
  }

  Future<ApiNoteRepository> register({
    required String email,
    required String displayName,
    required String password,
    required String confirmPassword,
  }) async {
    final data = await _post('/api/auth/register', {
      'email': email.trim(),
      'displayName': displayName.trim(),
      'password': password,
      'confirmPassword': confirmPassword,
    });
    return ApiNoteRepository.fromSession(baseUrl: _baseUrl, session: data);
  }

  Future<void> forgotPassword(String email) async {
    await _post('/api/auth/password/forgot', {'email': email.trim()});
  }

  Future<String> verifyResetCode(String email, String code) async {
    final data = await _post('/api/auth/password/verify-code', {
      'email': email.trim(),
      'code': code.trim(),
    });
    return data['resetTicket'] as String;
  }

  Future<void> resetPassword(
    String ticket,
    String password,
    String confirm,
  ) async {
    await _post('/api/auth/password/reset', {
      'resetTicket': ticket,
      'newPassword': password,
      'confirmPassword': confirm,
    });
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic> data = {};
      if (response.bodyBytes.isNotEmpty) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) return data;
      final errors = data['errors'];
      final messages = <String>[];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List)
            for (final error in value) {
              if (error is Map && error['message'] is String)
                messages.add(error['message'] as String);
              if (error is String) messages.add(error);
            }
        }
      }
      throw RepositoryException(
        messages.isNotEmpty
            ? messages.join('\n')
            : data['title'] as String? ??
                  'The request could not be completed. Please try again.',
        code: data['code'] as String?,
        statusCode: response.statusCode,
        details: data,
      );
    } on RepositoryException {
      rethrow;
    } on TimeoutException {
      throw const RepositoryException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const RepositoryException(
        'Could not reach Jotter. Check the server address and connection.',
      );
    } on FormatException {
      throw const RepositoryException(
        'The server returned an unexpected response.',
      );
    }
  }
}

extension AccountApi on ApiNoteRepository {
  Future<JotterAccount> getProfile() async {
    final value = JotterAccount.fromJson(await request('GET', '/api/me'));
    account = value;
    return value;
  }

  Future<JotterAccount> updateProfile(String name) async {
    final value = JotterAccount.fromJson(
      await request('PUT', '/api/me', body: {'displayName': name.trim()}),
    );
    account = value;
    return value;
  }

  Future<JotterPreferences> getPreferences() async =>
      JotterPreferences.fromJson(await request('GET', '/api/me/preferences'));
  Future<JotterPreferences> updatePreferences(
    JotterPreferences preferences,
  ) async => JotterPreferences.fromJson(
    await request('PUT', '/api/me/preferences', body: preferences.toJson()),
  );
  Future<Uint8List?> getAvatar() async {
    if (account.avatarUrl == null) return null;
    return download('/api/users/${account.id}/avatar');
  }

  Future<void> uploadAvatar(Uint8List bytes, String filename) async {
    final value = await upload('/api/me/avatar', bytes, filename);
    account = account.copyWith(avatarUrl: value['avatarUrl'] as String);
  }

  Future<void> removeAvatar() async {
    await request('DELETE', '/api/me/avatar');
    account = account.copyWith(clearAvatar: true);
  }

  Future<int> resendActivation() async {
    final value = await request('POST', '/api/auth/activation/resend');
    return (value['cooldownSeconds'] as num?)?.toInt() ?? 60;
  }

  Future<void> confirmActivation(String code) async {
    final value = await request(
      'POST',
      '/api/auth/activation/confirm',
      body: {'code': code.trim()},
    );
    replaceAccessToken(value['accessToken'] as String);
    account = account.copyWith(
      isActivated: value['isActivated'] as bool? ?? true,
    );
  }

  Future<void> changePassword(
    String current,
    String password,
    String confirm,
  ) async {
    final value = await request(
      'POST',
      '/api/auth/password/change',
      body: {
        'currentPassword': current,
        'newPassword': password,
        'confirmPassword': confirm,
      },
    );
    replaceAccessToken(value['accessToken'] as String);
  }
}

String accountErrorMessage(Object error) {
  if (error is! RepositoryException) return error.toString();
  final messages = <String>[];
  final requirements = error.details['requirements'];
  if (requirements is List) {
    for (final item in requirements) {
      if (item is Map && item['description'] is String)
        messages.add(item['description'] as String);
    }
  }
  final errors = error.details['errors'];
  if (errors is Map) {
    for (final values in errors.values) {
      if (values is List) {
        for (final item in values) {
          if (item is Map && item['message'] is String)
            messages.add(item['message'] as String);
          if (item is String) messages.add(item);
        }
      }
    }
  }
  return messages.isEmpty ? error.message : messages.toSet().join('\n');
}
