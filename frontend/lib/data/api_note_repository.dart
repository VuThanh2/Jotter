import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/jotter_account.dart';
import '../models/jotter_label.dart';
import '../models/jotter_note.dart';
import 'note_ids.dart';
import 'note_repository.dart';

class ApiNoteRepository extends NoteRepository {
  ApiNoteRepository._(this._baseUri, this._client, this._token, this.account);

  final Uri _baseUri;
  final http.Client _client;
  String _token;
  JotterAccount account;
  String get baseUrl => _baseUri.toString();
  void replaceAccessToken(String token) => _token = token;

  static ApiNoteRepository fromSession({
    required String baseUrl,
    required Map<String, dynamic> session,
    http.Client? client,
  }) {
    final uri = Uri.parse(baseUrl.trim());
    if (!['http', 'https'].contains(uri.scheme) ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const RepositoryException(
        'Enter a valid HTTP or HTTPS server URL.',
      );
    }
    return ApiNoteRepository._(
      uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), '')),
      client ?? http.Client(),
      session['accessToken'] as String,
      JotterAccount.fromJson(Map<String, dynamic>.from(session['user'] as Map)),
    );
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool idempotent = false,
    String? idempotencyKey,
  }) => _request(
    method,
    path,
    query: query,
    body: body,
    idempotent: idempotent,
    idempotencyKey: idempotencyKey,
  );
  final Map<String, JotterNote> _knownNotes = {};
  final Map<String, String> _pendingOperations = {};
  final Map<String, String> _pendingLabelIds = {};
  bool _closed = false;

  @override
  bool get isPreview => false;

  static Future<ApiNoteRepository> signIn({
    required String baseUrl,
    required String email,
    required String password,
    http.Client? client,
  }) async {
    final uri = Uri.tryParse(baseUrl.trim());
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
    final connection = client ?? http.Client();
    try {
      final base = uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
      final response = await connection
          .post(
            Uri.parse('$base/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
      final data = _readResponse(response);
      final user = data['user'] as Map<String, dynamic>;
      return ApiNoteRepository._(
        base,
        connection,
        data['accessToken'] as String,
        JotterAccount(
          id: user['userId'] as String,
          email: user['email'] as String,
          displayName: user['displayName'] as String,
          isActivated: user['isActivated'] as bool? ?? false,
          avatarUrl: user['avatarUrl'] as String?,
        ),
      );
    } on RepositoryException {
      connection.close();
      rethrow;
    } on TimeoutException {
      connection.close();
      throw const RepositoryException(
        'The server took too long to respond. Check the server URL and try again.',
      );
    } on http.ClientException {
      connection.close();
      throw const RepositoryException(
        'Could not reach Jotter. Check that the API is running and the server URL is correct.',
      );
    } catch (_) {
      connection.close();
      throw const RepositoryException(
        'The server returned an unexpected response.',
      );
    }
  }

  @override
  Future<List<JotterNote>> listNotes({String? query}) async {
    final notes = <JotterNote>[];
    String? cursor;
    final seenCursors = <String>{};
    final search = query?.trim() ?? '';
    do {
      final data = await _request(
        'GET',
        '/api/notes',
        query: {
          'scope': 'All',
          'limit': '100',
          'cursor': ?cursor,
          if (search.isNotEmpty) 'q': search,
        },
      );
      for (final item in data['items'] as List<dynamic>) {
        final note = _parseNote(item as Map<String, dynamic>, detail: false);
        _knownNotes[note.id] = note;
        notes.add(note);
      }
      cursor = data['nextCursor'] as String?;
      if (cursor != null && !seenCursors.add(cursor)) {
        throw const RepositoryException(
          'The server returned an invalid notes page.',
        );
      }
    } while (cursor != null);
    return notes;
  }

  @override
  Future<JotterNote> getNote(String id) async {
    final data = await _request('GET', '/api/notes/$id');
    final note = _parseNote(data, detail: true);
    _knownNotes[id] = note;
    return note;
  }

  @override
  Future<List<JotterLabel>> listLabels() async {
    final data = await _request('GET', '/api/labels');
    return (data['items'] as List<dynamic>).map((item) {
      final label = item as Map<String, dynamic>;
      return JotterLabel(
        id: label['labelId'] as String,
        name: label['name'] as String,
      );
    }).toList();
  }

  @override
  Future<JotterNote> saveNote(JotterNote note, {bool isNew = false}) async {
    if (!note.contentLoaded) {
      throw const RepositoryException(
        'Open the complete note before making changes.',
      );
    }
    validateNote(note);
    if (!note.canEdit) {
      throw const RepositoryException(
        'You have read-only access to this note.',
      );
    }
    final data = await _request(
      isNew ? 'POST' : 'PUT',
      isNew ? '/api/notes' : '/api/notes/${note.id}',
      body: {
        if (isNew) 'noteId': note.id,
        if (isNew) 'conflictOfNoteId': note.conflictOfNoteId,
        if (!isNew) 'baseVersion': note.version,
        'title': note.title,
        'content': note.content,
      },
      idempotent: true,
    );
    final saved = note.copyWith(
      version: (data['version'] as num).toInt(),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
      createdAt: isNew
          ? DateTime.parse(data['createdAt'] as String)
          : note.createdAt,
      preview: note.isProtected ? '' : _preview(note.content),
      contentLoaded: true,
    );
    _knownNotes[note.id] = saved;
    return saved;
  }

  @override
  Future<JotterNote> pinNote(JotterNote note, bool pinned) async {
    _ensureOwned(note);
    await _request(
      'PUT',
      '/api/notes/${note.id}/pin',
      body: {'isPinned': pinned},
      idempotent: true,
    );
    final saved = note.copyWith(isPinned: pinned);
    _knownNotes[note.id] = saved;
    return saved;
  }

  @override
  Future<void> deleteNote(String id) async {
    await _request('DELETE', '/api/notes/$id', idempotent: true);
    _knownNotes.remove(id);
  }

  @override
  Future<JotterLabel> createLabel(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      throw const RepositoryException(
        'Use a label name between 1 and 50 characters.',
      );
    }
    final data = await _request(
      'POST',
      '/api/labels',
      body: {
        'labelId': _pendingLabelIds.putIfAbsent(trimmed, newNoteId),
        'name': trimmed,
      },
      idempotent: true,
    );
    _pendingLabelIds.remove(trimmed);
    return JotterLabel(
      id: data['labelId'] as String,
      name: data['name'] as String,
    );
  }

  @override
  Future<JotterNote> setLabels(JotterNote note, List<String> ids) async {
    _ensureOwned(note);
    final data = await _request(
      'PUT',
      '/api/notes/${note.id}/labels',
      body: {'labelIds': ids},
      idempotent: true,
    );
    final saved = note.copyWith(
      labelIds: List<String>.from(data['labelIds'] as List),
    );
    _knownNotes[note.id] = saved;
    return saved;
  }

  @override
  Future<JotterLabel> renameLabel(String id, String name) async {
    final data = await _request(
      'PUT',
      '/api/labels/$id',
      body: {'name': name.trim()},
      idempotent: true,
    );
    return JotterLabel(
      id: data['labelId'] as String,
      name: data['name'] as String,
    );
  }

  @override
  Future<void> deleteLabel(String id) async {
    await _request('DELETE', '/api/labels/$id', idempotent: true);
  }

  @override
  Future<JotterNote> unlockNote(String id, String password) async {
    await _request(
      'POST',
      '/api/notes/$id/unlock',
      body: {'password': password},
    );
    return getNote(id);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    try {
      await _request(
        'POST',
        '/api/auth/logout',
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Signing out must still discard the in-memory session when offline.
    } finally {
      _closed = true;
      _knownNotes.clear();
      _pendingOperations.clear();
      _pendingLabelIds.clear();
      _client.close();
    }
  }

  void dispose() {
    _closed = true;
    _knownNotes.clear();
    _pendingOperations.clear();
    _pendingLabelIds.clear();
    _client.close();
  }

  Uri _uri(String path) {
    if (!path.startsWith('/') || path.startsWith('//'))
      throw const RepositoryException('Invalid API path.');
    return Uri.parse('$_baseUri$path');
  }

  Future<Uint8List> download(String path) async {
    if (_closed) throw const RepositoryException('This session has ended.');
    try {
      final response = await _client
          .get(_uri(path), headers: {'Authorization': 'Bearer $_token'})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300)
        _readResponse(response);
      return response.bodyBytes;
    } on TimeoutException {
      throw const RepositoryException(
        'Download timed out. Try again.',
        code: 'NetworkUnavailable',
      );
    } on http.ClientException {
      throw const RepositoryException(
        'Could not reach Jotter. Check your connection.',
        code: 'NetworkUnavailable',
      );
    }
  }

  Future<Map<String, dynamic>> upload(
    String path,
    Uint8List bytes,
    String filename, {
    String field = 'file',
  }) async {
    if (_closed) throw const RepositoryException('This session has ended.');
    final upload = http.MultipartRequest('POST', _uri(path));
    upload.headers.addAll({
      'Authorization': 'Bearer $_token',
      'Idempotency-Key': newNoteId(),
    });
    upload.files.add(
      http.MultipartFile.fromBytes(field, bytes, filename: filename),
    );
    try {
      return _readResponse(
        await _client
            .send(upload)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 60)),
      );
    } on TimeoutException {
      throw const RepositoryException(
        'Upload timed out. Refresh the files before retrying.',
        code: 'NetworkUnavailable',
      );
    } on http.ClientException {
      throw const RepositoryException(
        'Could not upload the file. Check your connection.',
        code: 'NetworkUnavailable',
      );
    }
  }

  Stream<String> stream(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) {
    final abort = Completer<void>();
    StreamSubscription<String>? subscription;
    var cancelled = false;
    late StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () async {
        try {
          if (_closed)
            throw const RepositoryException('This session has ended.');
          final request = http.AbortableRequest(
            method,
            _uri(path),
            abortTrigger: abort.future,
          );
          request.headers.addAll({
            'Authorization': 'Bearer $_token',
            'Accept': 'text/event-stream',
            'Content-Type': 'application/json',
          });
          if (body != null) request.body = jsonEncode(body);
          final response = await _client
              .send(request)
              .timeout(const Duration(seconds: 90));
          if (response.statusCode < 200 || response.statusCode >= 300)
            _readResponse(await http.Response.fromStream(response));
          if (cancelled) return;
          subscription = response.stream
              .transform(utf8.decoder)
              .timeout(const Duration(seconds: 90))
              .listen(
                controller.add,
                onError: (Object error, StackTrace stack) {
                  if (!cancelled) controller.addError(error, stack);
                },
                onDone: controller.close,
              );
        } catch (error, stack) {
          if (!cancelled) {
            controller.addError(error, stack);
            await controller.close();
          }
        }
      },
      onCancel: () async {
        cancelled = true;
        if (!abort.isCompleted) abort.complete();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  void _ensureOwned(JotterNote note) {
    if (!note.isOwned) {
      throw const RepositoryException('Only the owner can organize this note.');
    }
  }

  JotterNote _parseNote(Map<String, dynamic> data, {required bool detail}) {
    final id = data['noteId'] as String;
    final previous = _knownNotes[id];
    final owned = detail
        ? data['ownerId'] == account.id
        : data['isPinned'] != null;
    final content = detail ? (data['content'] as String? ?? '') : '';
    final protected = data['isProtected'] as bool? ?? false;
    return JotterNote(
      id: id,
      title: data['title'] as String? ?? '',
      content: content,
      preview: protected
          ? ''
          : (detail ? _preview(content) : data['preview'] as String? ?? ''),
      version: (data['version'] as num).toInt(),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
      createdAt: data['createdAt'] is String
          ? DateTime.parse(data['createdAt'] as String)
          : previous?.createdAt ?? DateTime.parse(data['updatedAt'] as String),
      isPinned: data['isPinned'] as bool? ?? false,
      isProtected: protected,
      isShared: data['isShared'] as bool? ?? previous?.isShared ?? !owned,
      isOwned: owned,
      canEdit: detail ? ['Owner', 'Edit'].contains(data['permission']) : owned,
      contentLoaded: detail && data['content'] != null,
      conflictOfNoteId: data['conflictOfNoteId'] as String?,
      labelIds: List<String>.from(data['labelIds'] as List? ?? const []),
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool idempotent = false,
    String? idempotencyKey,
  }) async {
    if (_closed) {
      throw const RepositoryException('This session has ended. Sign in again.');
    }
    final uri = _uri(path).replace(queryParameters: query);
    final operation = '$method $path ${jsonEncode(body)}';
    final request = http.Request(method, uri);
    request.headers.addAll({
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      if (idempotent || idempotencyKey != null)
        'Idempotency-Key':
            idempotencyKey ??
            _pendingOperations.putIfAbsent(operation, newNoteId),
    });
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(Duration(seconds: path == '/api/ai/ask' ? 90 : 15));
      final data = _readResponse(response);
      _pendingOperations.remove(operation);
      return data;
    } on RepositoryException {
      rethrow;
    } on TimeoutException {
      throw const RepositoryException(
        'The server took too long to respond. Your draft is still here.',
        code: 'NetworkUnavailable',
      );
    } on http.ClientException {
      throw const RepositoryException(
        'Could not reach Jotter. Check your connection and try again.',
        code: 'NetworkUnavailable',
      );
    } on FormatException {
      throw const RepositoryException(
        'The server returned an unexpected response.',
      );
    }
  }

  static Map<String, dynamic> _readResponse(http.Response response) {
    Map<String, dynamic> data = {};
    if (response.bodyBytes.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) rethrow;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final code = data['code'] as String?;
    final message = switch ((response.statusCode, code)) {
      (409, 'VersionConflict') => 'This note changed on another device. Your draft is still here. Copy it before reloading the latest version.',
      (401, _) => 'Your email or password is incorrect, or your session has expired. Please sign in again.',
      (423, _) => 'This note is locked. Enter its password to open it.',
      (429, _) => 'Too many attempts. Please wait a moment and try again.',
      _ =>
        data['title'] as String? ??
            'Jotter could not complete this request. Please try again.',
    };
    throw RepositoryException(
      message,
      code: code,
      statusCode: response.statusCode,
      details: data,
    );
  }

  static String _preview(String content) =>
      content.length > 200 ? content.substring(0, 200) : content;
}
