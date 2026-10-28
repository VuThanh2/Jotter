import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/jotter_label.dart';
import '../models/jotter_note.dart';
import '../models/sync_status.dart';
import 'api_note_repository.dart';
import 'local_workspace_store.dart';
import 'note_repository.dart';
import 'sync_api.dart';

/// Own, unprotected notes have a durable cache and outbox. Shared and protected
/// note bodies require a live server and are never written to device storage.
class OfflineNoteRepository extends NoteRepository {
  OfflineNoteRepository._(
    this.remote,
    this._store,
    this._enableRealtime,
    this._syncInterval,
  ) : storageKey =
          'jotter.workspace.v1.${Uri.encodeComponent(remote.baseUrl)}.${remote.account.id}';

  static Future<OfflineNoteRepository> open(
    ApiNoteRepository remote, {
    WorkspaceStore? store,
    bool enableRealtime = true,
    bool startBackground = true,
    Duration syncInterval = const Duration(seconds: 30),
  }) async {
    final repository = OfflineNoteRepository._(
      remote,
      store ?? PreferencesWorkspaceStore(),
      enableRealtime,
      syncInterval,
    );
    await repository._restore();
    if (startBackground) {
      repository._poll = Timer.periodic(
        repository._syncInterval,
        (_) => unawaited(repository.synchronize()),
      );
      unawaited(repository.synchronize());
      if (enableRealtime) unawaited(repository._connectRealtime());
    }
    return repository;
  }

  final ApiNoteRepository remote;
  final WorkspaceStore _store;
  final bool _enableRealtime;
  final Duration _syncInterval;
  final String storageKey;
  final Map<String, JotterNote> _notes = {};
  final Map<String, JotterLabel> _labels = {};
  final Map<String, Map<String, dynamic>> _shares = {};
  final List<_QueuedOperation> _outbox = [];
  final List<_QueuedOperation> _volatileProtectedDrafts = [];
  final ValueNotifier<WorkspaceSyncStatus> _status = ValueNotifier(
    const WorkspaceSyncStatus(),
  );
  final StreamController<Map<String, dynamic>> _events =
      StreamController.broadcast();
  Future<void>? _synchronizing;
  Future<void> _writeTail = Future.value();
  Timer? _poll;
  Timer? _ping;
  Timer? _reconnect;
  StreamSubscription<dynamic>? _socketSubscription;
  WebSocketChannel? _socket;
  bool _connecting = false;
  bool _disposed = false;
  bool _storageAvailable = true;
  bool _isOffline = false;
  bool _realtimeConnected = false;
  int _cursor = 0;
  int _reconnectAttempts = 0;
  DateTime? _lastSynced;
  String? _error;
  String? _watchedNote;

  @override
  bool get isPreview => false;
  ValueListenable<WorkspaceSyncStatus> get syncStatus => _status;
  Stream<Map<String, dynamic>> get realtimeEvents => _events.stream;
  bool get isOffline => _isOffline;
  List<JotterNote> get cachedNotes => List.unmodifiable(_notes.values);
  List<JotterLabel> get cachedLabels => List.unmodifiable(_labels.values);

  List<PendingWorkspaceChange> get pendingChanges => List.unmodifiable(
    [..._outbox, ..._volatileProtectedDrafts].map(
      (operation) => PendingWorkspaceChange(
        id: operation.id,
        kind: operation.kind,
        title:
            operation.payload['title'] as String? ??
            operation.payload['name'] as String? ??
            operation.kind,
        noteId: operation.noteId,
        error: operation.error,
        code: operation.code,
      ),
    ),
  );

  void _publish({bool syncing = false}) {
    if (_disposed) return;
    _status.value = WorkspaceSyncStatus(
      pendingCount: _outbox.length + _volatileProtectedDrafts.length,
      conflictCount:
          _outbox.where((operation) => operation.error != null).length +
          _volatileProtectedDrafts.length,
      isSyncing: syncing,
      isOffline: _isOffline,
      realtimeConnected: _realtimeConnected,
      lastSyncedAt: _lastSynced,
      error: _error,
    );
  }

  Future<void> _restore() async {
    try {
      final serialized = await _store.read(storageKey);
      if (serialized == null) return;
      final snapshot = jsonDecode(serialized) as Map<String, dynamic>;
      if (snapshot['schema'] != 1) {
        throw const FormatException('Unsupported workspace cache');
      }
      _cursor = (snapshot['cursor'] as num?)?.toInt() ?? 0;
      _lastSynced = DateTime.tryParse(
        snapshot['lastSyncedAt'] as String? ?? '',
      );
      for (final item in snapshot['notes'] as List<dynamic>? ?? []) {
        final note = _safeForDisk(
          JotterNote.fromJson(Map<String, dynamic>.from(item as Map)),
        );
        _notes[note.id] = note;
      }
      for (final item in snapshot['labels'] as List<dynamic>? ?? []) {
        final label = Map<String, dynamic>.from(item as Map);
        _labels[label['id'] as String] = JotterLabel(
          id: label['id'] as String,
          name: label['name'] as String,
        );
      }
      for (final item in snapshot['outbox'] as List<dynamic>? ?? []) {
        final operation = _QueuedOperation.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        // A corrupted or old snapshot must never resurrect private note content.
        final draft = operation.payload['note'];
        if (draft is Map &&
            (draft['isProtected'] == true || draft['isOwned'] == false)) {
          continue;
        }
        _outbox.add(operation);
      }
      for (final item in snapshot['shares'] as List<dynamic>? ?? []) {
        final share = Map<String, dynamic>.from(item as Map);
        _shares[share['shareId'] as String] = share;
      }
      _isOffline = true;
      _publish();
    } catch (_) {
      _storageAvailable = false;
      _error = 'Device storage could not be read. Online notes still work; keep unsaved drafts open.';
      _publish();
    }
  }

  JotterNote _safeForDisk(JotterNote note) => note.isProtected || !note.isOwned
      ? note.copyWith(content: '', preview: '', contentLoaded: false)
      : note;

  Future<void> _persist() async {
    if (_disposed) return;
    if (!_storageAvailable) {
      throw const RepositoryException(
        'Device storage is unavailable. Keep your draft open until you are online.',
        code: 'StorageUnavailable',
      );
    }
    final snapshot = jsonEncode({
      'schema': 1,
      'cursor': _cursor,
      'lastSyncedAt': _lastSynced?.toIso8601String(),
      'notes': _notes.values
          .map((note) => _safeForDisk(note).toJson())
          .toList(),
      'labels': _labels.values
          .map((label) => {'id': label.id, 'name': label.name})
          .toList(),
      'outbox': _outbox.map((operation) => operation.toJson()).toList(),
      'shares': _shares.values.toList(),
    });
    final write = _writeTail
        .catchError((Object _) {})
        .then((_) => _store.write(storageKey, snapshot));
    _writeTail = write;
    try {
      await write;
    } catch (_) {
      throw const RepositoryException(
        'This device could not save your draft. Keep the editor open and free some storage.',
        code: 'StorageUnavailable',
      );
    }
  }

  bool _networkFailure(Object error) =>
      error is RepositoryException &&
      (error.code == 'NetworkUnavailable' ||
          (error.statusCode == null &&
              (error.message.contains('Could not reach') ||
                  error.message.contains('too long to respond'))));

  bool _hasPendingNote(String id) =>
      _outbox.any((operation) => operation.noteId == id);
  bool _hasPendingLabel(String id) =>
      _outbox.any((operation) => operation.payload['labelId'] == id);

  @override
  Future<List<JotterNote>> listNotes({String? query}) async {
    await synchronize();
    final search = query?.trim() ?? '';
    if (search.isEmpty) return _notes.values.toList();
    if (!_isOffline) {
      try {
        final serverResults = await remote.listNotes(query: search);
        final matches = {
          for (final note in serverResults) note.id: _notes[note.id] ?? note,
        };
        for (final note in _notes.values.where(
          (note) => _hasPendingNote(note.id),
        )) {
          if (_matches(note, search)) {
            matches[note.id] = note;
          } else {
            matches.remove(note.id);
          }
        }
        return matches.values.toList();
      } catch (error) {
        if (!_networkFailure(error)) rethrow;
        _isOffline = true;
        _publish();
      }
    }
    return _notes.values.where((note) => _matches(note, search)).toList();
  }

  bool _matches(JotterNote note, String query) =>
      '${note.title} ${note.isProtected
              ? ''
              : note.contentLoaded
              ? note.content
              : note.preview}'
          .toLowerCase()
          .contains(query.toLowerCase());

  @override
  Future<JotterNote> getNote(String id) async {
    final pending = _notes[id];
    if (_hasPendingNote(id) &&
        pending != null &&
        pending.isOwned &&
        !pending.isProtected) {
      return pending;
    }
    try {
      final note = await remote.getNote(id);
      if (_disposed) {
        throw const RepositoryException(
          'This workspace has closed. Sign in again.',
        );
      }
      _notes[id] = note;
      _isOffline = false;
      await _persistIfAvailable();
      _publish();
      return note;
    } catch (error) {
      if (error is RepositoryException &&
          error.statusCode == 423 &&
          pending != null) {
        _notes[id] = pending.copyWith(
          isProtected: true,
          content: '',
          preview: '',
          contentLoaded: false,
        );
        await _persistIfAvailable();
        rethrow;
      }
      if (error is RepositoryException &&
          [403, 404].contains(error.statusCode)) {
        _notes.remove(id);
        await _persistIfAvailable();
        rethrow;
      }
      if (!_networkFailure(error)) rethrow;
      _isOffline = true;
      _publish();
      if (pending != null &&
          pending.isOwned &&
          !pending.isProtected &&
          pending.contentLoaded) {
        return pending;
      }
      throw const RepositoryException(
        'This note needs an online connection. Protected and shared note content is not stored offline.',
        code: 'NetworkUnavailable',
      );
    }
  }

  @override
  Future<List<JotterLabel>> listLabels() async {
    await synchronize();
    return _labels.values.toList();
  }

  @override
  Future<JotterNote> saveNote(JotterNote note, {bool isNew = false}) async {
    validateNote(note);
    if (!note.canEdit || !note.contentLoaded) {
      throw const RepositoryException(
        'Open the complete editable note before saving.',
      );
    }
    if (note.isProtected || !note.isOwned || !_storageAvailable) {
      final saved = await remote.saveNote(note, isNew: isNew);
      _notes[saved.id] = saved;
      await _persistIfAvailable();
      return saved;
    }
    final operation = _QueuedOperation(
      id: generateUuid(),
      kind: 'save',
      payload: {
        'noteId': note.id,
        'title': note.title,
        'isNew': isNew,
        'note': note.toJson(),
      },
    );
    final local = note.copyWith(
      updatedAt: DateTime.now(),
      preview: note.content.length > 200
          ? note.content.substring(0, 200)
          : note.content,
    );
    final old = _notes[note.id];
    _notes[note.id] = local;
    _outbox.add(operation);
    try {
      await _persist();
    } catch (_) {
      _outbox.remove(operation);
      if (old == null) {
        _notes.remove(note.id);
      } else {
        _notes[note.id] = old;
      }
      rethrow;
    }
    await synchronize();
    if (operation.error != null) {
      throw RepositoryException(
        operation.error!,
        code: operation.code,
        statusCode: operation.statusCode,
      );
    }
    return _notes[note.id] ?? local;
  }

  @override
  Future<JotterNote> pinNote(JotterNote note, bool pinned) async {
    if (!note.isOwned) {
      throw const RepositoryException('Only the owner can pin this note.');
    }
    final updated = note.copyWith(isPinned: pinned);
    await _queueMetadata('pin', {
      'noteId': note.id,
      'title': note.title,
      'isPinned': pinned,
    }, () => _notes[note.id] = updated);
    return _notes[note.id] ?? updated;
  }

  @override
  Future<void> deleteNote(String id) async {
    final note = _notes[id];
    if (note != null && !note.isOwned) {
      throw const RepositoryException('Only the owner can delete this note.');
    }
    await _queueMetadata('delete', {
      'noteId': id,
      'title': note?.title ?? 'Delete note',
    }, () => _notes.remove(id));
  }

  @override
  Future<JotterLabel> createLabel(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      throw const RepositoryException(
        'Use a label name between 1 and 50 characters.',
      );
    }
    if (_labels.values.any(
      (label) => label.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      throw const RepositoryException('A label with this name already exists.');
    }
    final label = JotterLabel(id: generateUuid(), name: trimmed);
    await _queueMetadata('createLabel', {
      'labelId': label.id,
      'name': label.name,
    }, () => _labels[label.id] = label);
    return label;
  }

  @override
  Future<JotterLabel> renameLabel(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      throw const RepositoryException(
        'Use a label name between 1 and 50 characters.',
      );
    }
    final label = JotterLabel(id: id, name: trimmed);
    await _queueMetadata('renameLabel', {
      'labelId': id,
      'name': trimmed,
    }, () => _labels[id] = label);
    return label;
  }

  @override
  Future<void> deleteLabel(String id) async {
    await _queueMetadata(
      'deleteLabel',
      {'labelId': id, 'name': _labels[id]?.name ?? 'Delete label'},
      () {
        _labels.remove(id);
        for (final note in _notes.values.toList()) {
          _notes[note.id] = note.copyWith(
            labelIds: note.labelIds.where((labelId) => labelId != id).toList(),
          );
        }
      },
    );
  }

  @override
  Future<JotterNote> setLabels(JotterNote note, List<String> ids) async {
    if (!note.isOwned) {
      throw const RepositoryException('Only the owner can organize this note.');
    }
    final updated = note.copyWith(labelIds: ids);
    await _queueMetadata('labels', {
      'noteId': note.id,
      'title': note.title,
      'labelIds': ids,
    }, () => _notes[note.id] = updated);
    return _notes[note.id] ?? updated;
  }

  Future<void> _queueMetadata(
    String kind,
    Map<String, dynamic> payload,
    void Function() update,
  ) async {
    final operation = _QueuedOperation(
      id: generateUuid(),
      kind: kind,
      payload: payload,
    );
    // Persist the operation before considering the user's action saved.
    _outbox.add(operation);
    try {
      await _persist();
    } catch (_) {
      _outbox.remove(operation);
      rethrow;
    }
    update();
    await _persist();
    await synchronize();
    if (operation.error != null) {
      throw RepositoryException(
        operation.error!,
        code: operation.code,
        statusCode: operation.statusCode,
      );
    }
  }

  @override
  Future<JotterNote> unlockNote(String id, String password) async {
    final note = await remote.unlockNote(id, password);
    _notes[id] = note;
    await _persistIfAvailable();
    return note;
  }

  Future<void> _persistIfAvailable() async {
    if (_storageAvailable) await _persist();
  }

  void _persistInBackground() {
    unawaited(
      _persistIfAvailable().catchError((Object error) {
        _error = error.toString();
        _publish();
      }),
    );
  }

  /// A draft moved to session memory after another device protected its note is
  /// available for review, but deliberately excluded from persistent snapshots.
  JotterNote? pendingDraft(String operationId) {
    final operation = [
      ..._outbox,
      ..._volatileProtectedDrafts,
    ].where((item) => item.id == operationId).firstOrNull;
    final value = operation?.payload['note'];
    return value is Map
        ? JotterNote.fromJson(Map<String, dynamic>.from(value))
        : null;
  }

  Future<void> synchronize() {
    if (_disposed) return Future.value();
    return _synchronizing ??= _synchronize().whenComplete(
      () => _synchronizing = null,
    );
  }

  Future<void> _synchronize() async {
    _publish(syncing: true);
    try {
      await _flush();
      if (_disposed) return;
      if (_isOffline) return;
      await _pull();
      _lastSynced = DateTime.now();
      _isOffline = false;
      if (_storageAvailable) await _persist();
      if (_error == null ||
          !_outbox.any((operation) => operation.error != null)) {
        _error = null;
      }
      if (!_disposed) _events.add({'type': 'workspaceSynced'});
    } catch (error) {
      if (_networkFailure(error)) {
        _isOffline = true;
        _error = 'Offline. Changes to your own unprotected notes are saved on this device and will sync when connected.';
      } else {
        _error = error.toString();
      }
    } finally {
      _publish();
    }
  }

  Future<void> _flush() async {
    _isOffline = false;
    final blockedNotes = <String>{};
    for (final operation in _outbox.toList()) {
      if (_disposed) return;
      if (operation.error != null) {
        if (operation.noteId != null) blockedNotes.add(operation.noteId!);
        continue;
      }
      if (operation.noteId != null && blockedNotes.contains(operation.noteId)) {
        continue;
      }
      try {
        final saved = await _sendOperation(operation);
        if (_disposed) return;
        _outbox.remove(operation);
        if (saved != null) {
          _rewriteQueuedVersions(saved);
          if (!_hasPendingNote(saved.id)) _notes[saved.id] = saved;
        }
        await _persistIfAvailable();
      } catch (error) {
        if (_networkFailure(error)) {
          _isOffline = true;
          return;
        }
        operation.error = error.toString();
        if (error is RepositoryException) {
          operation.code = error.code;
          operation.statusCode = error.statusCode;
        }
        if (operation.noteId != null) blockedNotes.add(operation.noteId!);
        _error =
            'Some saved changes need attention. Review them in sync status.';
        await _persistIfAvailable();
      }
    }
  }

  void _rewriteQueuedVersions(JotterNote saved) {
    for (final operation in _outbox.where(
      (operation) => operation.kind == 'save' && operation.noteId == saved.id,
    )) {
      final pending = JotterNote.fromJson(
        Map<String, dynamic>.from(operation.payload['note'] as Map),
      );
      operation.payload['note'] = pending
          .copyWith(version: saved.version)
          .toJson();
      operation.payload['isNew'] = false;
    }
    final local = _notes[saved.id];
    if (local != null && _hasPendingNote(saved.id)) {
      _notes[saved.id] = local.copyWith(version: saved.version);
    }
  }

  Future<JotterNote?> _sendOperation(_QueuedOperation operation) async {
    final data = operation.payload;
    final noteId = operation.noteId;
    Map<String, dynamic> result;
    switch (operation.kind) {
      case 'save':
        final draft = JotterNote.fromJson(
          Map<String, dynamic>.from(data['note'] as Map),
        );
        final creating = data['isNew'] == true;
        result = await remote.request(
          creating ? 'POST' : 'PUT',
          creating ? '/api/notes' : '/api/notes/$noteId',
          body: {
            if (creating) 'noteId': draft.id,
            if (creating) 'conflictOfNoteId': draft.conflictOfNoteId,
            if (!creating) 'baseVersion': draft.version,
            'title': draft.title,
            'content': draft.content,
          },
          idempotencyKey: operation.id,
        );
        return draft.copyWith(
          version: (result['version'] as num).toInt(),
          updatedAt: DateTime.parse(result['updatedAt'] as String),
          createdAt: creating
              ? DateTime.parse(result['createdAt'] as String)
              : draft.createdAt,
        );
      case 'pin':
        await remote.request(
          'PUT',
          '/api/notes/$noteId/pin',
          body: {'isPinned': data['isPinned']},
          idempotencyKey: operation.id,
        );
      case 'labels':
        await remote.request(
          'PUT',
          '/api/notes/$noteId/labels',
          body: {'labelIds': data['labelIds']},
          idempotencyKey: operation.id,
        );
      case 'delete':
        await remote.request(
          'DELETE',
          '/api/notes/$noteId',
          idempotencyKey: operation.id,
        );
      case 'createLabel':
        await remote.request(
          'POST',
          '/api/labels',
          body: {'labelId': data['labelId'], 'name': data['name']},
          idempotencyKey: operation.id,
        );
      case 'renameLabel':
        await remote.request(
          'PUT',
          '/api/labels/${data['labelId']}',
          body: {'name': data['name']},
          idempotencyKey: operation.id,
        );
      case 'deleteLabel':
        await remote.request(
          'DELETE',
          '/api/labels/${data['labelId']}',
          idempotencyKey: operation.id,
        );
      default:
        throw const RepositoryException(
          'This queued change is not recognized.',
        );
    }
    return null;
  }

  Future<void> _pull() async {
    var first = true;
    var restarts = 0;
    final previousProtection = {
      for (final note in _notes.values) note.id: note.isProtected,
    };
    while (!_disposed) {
      final page = await remote.pullChanges(since: _cursor);
      if (_disposed) return;
      if (page['fullResyncRequired'] == true) {
        if (++restarts > 1) {
          throw const RepositoryException(
            'The server could not establish a fresh sync snapshot.',
          );
        }
        _cursor = 0;
        first = true;
        continue;
      }
      if (first && _cursor == 0) {
        _notes.removeWhere((id, _) => !_hasPendingNote(id));
        _labels.removeWhere((id, _) => !_hasPendingLabel(id));
        _shares.clear();
      }
      first = false;
      for (final value in page['notes'] as List<dynamic>? ?? []) {
        final item = Map<String, dynamic>.from(value as Map);
        final id = item['noteId'] as String;
        if (item['deletedAt'] != null) {
          if (!_hasPendingNote(id)) _notes.remove(id);
          continue;
        }
        final protected = item['isProtected'] == true;
        final owned = item['ownerId'] == remote.account.id;
        final newlyProtected =
            protected &&
            (_notes[id]?.isProtected ?? previousProtection[id]) == false;
        previousProtection[id] = protected;
        if (protected) {
          // A newly enabled password must scrub a previously cached body now,
          // including drafts which were edited before the other device locked it.
          final drafts = _outbox
              .where(
                (operation) =>
                    operation.noteId == id && operation.kind == 'save',
              )
              .toList();
          for (final operation in drafts) {
            final draft = JotterNote.fromJson(
              Map<String, dynamic>.from(operation.payload['note'] as Map),
            );
            operation.payload['note'] = draft
                .copyWith(isProtected: true)
                .toJson();
            operation.error = 'This note was protected on another device. Its unsent draft is now kept only in this session. Open or copy its text before closing the app; unlock the original note before saving.';
            operation.code = 'ProtectedDraft';
            _volatileProtectedDrafts.add(operation);
            _outbox.remove(operation);
            if (!_disposed) {
              _events.add({
                'type': 'protectedDraftNeedsAttention',
                'noteId': id,
              });
            }
          }
        }
        if (newlyProtected && !_disposed) {
          _events.add({
            'type': 'accessRevoked',
            'noteId': id,
            'isProtected': true,
          });
        }
        if (_hasPendingNote(id) && !protected) continue;
        final content = protected ? '' : item['content'] as String? ?? '';
        _notes[id] = JotterNote(
          id: id,
          title: item['title'] as String? ?? '',
          content: content,
          preview: protected
              ? ''
              : content.length > 200
              ? content.substring(0, 200)
              : content,
          createdAt: DateTime.parse(item['createdAt'] as String),
          updatedAt: DateTime.parse(item['updatedAt'] as String),
          version: (item['version'] as num).toInt(),
          isProtected: protected,
          isOwned: owned,
          isPinned: item['isPinned'] == true,
          isShared: !owned || _notes[id]?.isShared == true,
          canEdit: ['Owner', 'Edit'].contains(item['permission']),
          contentLoaded: !protected && item['content'] != null,
          labelIds: List<String>.from(item['labelIds'] as List? ?? []),
          conflictOfNoteId: item['conflictOfNoteId'] as String?,
        );
      }
      for (final value in page['labels'] as List<dynamic>? ?? []) {
        final label = Map<String, dynamic>.from(value as Map);
        final id = label['labelId'] as String;
        if (_hasPendingLabel(id)) continue;
        if (label['deletedAt'] != null) {
          _labels.remove(id);
        } else {
          _labels[id] = JotterLabel(id: id, name: label['name'] as String);
        }
      }
      for (final value in page['shares'] as List<dynamic>? ?? []) {
        final share = Map<String, dynamic>.from(value as Map);
        _shares[share['shareId'] as String] = share;
      }
      for (final share in _shares.values) {
        final id = share['noteId'] as String;
        if (share['recipientUserId'] != remote.account.id ||
            share['revokedAt'] == null) {
          continue;
        }
        final stillShared = _shares.values.any(
          (grant) =>
              grant['noteId'] == id &&
              grant['recipientUserId'] == remote.account.id &&
              grant['revokedAt'] == null,
        );
        if (stillShared) continue;
        _notes.remove(id);
        _outbox.removeWhere((operation) => operation.noteId == id);
        if (!_disposed) _events.add({'type': 'accessRevoked', 'noteId': id});
      }
      for (final note in _notes.values.where((note) => note.isOwned).toList()) {
        _notes[note.id] = note.copyWith(
          isShared: _shares.values.any(
            (share) => share['noteId'] == note.id && share['revokedAt'] == null,
          ),
        );
      }
      final next = (page['nextChangeSeq'] as num?)?.toInt() ?? _cursor;
      if (page['hasMore'] == true && next <= _cursor) {
        throw const RepositoryException(
          'The server returned an invalid sync cursor.',
        );
      }
      _cursor = next;
      await _persistIfAvailable();
      if (page['hasMore'] != true) break;
    }
  }

  Future<void> discardPending(String operationId) async {
    final operation = [
      ..._outbox,
      ..._volatileProtectedDrafts,
    ].where((item) => item.id == operationId).firstOrNull;
    if (operation == null) return;
    final noteId = operation.noteId;
    _outbox.removeWhere(
      (item) =>
          item.id == operationId || (noteId != null && item.noteId == noteId),
    );
    _volatileProtectedDrafts.removeWhere(
      (item) =>
          item.id == operationId || (noteId != null && item.noteId == noteId),
    );
    if (noteId != null) _notes.remove(noteId);
    _cursor = 0;
    await _persist();
    await synchronize();
    _publish();
  }

  Future<JotterNote> recoverConflictAsCopy(String operationId) async {
    final operation = [
      ..._outbox,
      ..._volatileProtectedDrafts,
    ].where((item) => item.id == operationId).firstOrNull;
    if (operation == null || operation.kind != 'save') {
      throw const RepositoryException('This change has no note draft to copy.');
    }
    final latest =
        _outbox
            .where(
              (item) => item.kind == 'save' && item.noteId == operation.noteId,
            )
            .lastOrNull ??
        operation;
    final original = JotterNote.fromJson(
      Map<String, dynamic>.from(latest.payload['note'] as Map),
    );
    if (original.isProtected) {
      throw const RepositoryException(
        'Protected notes cannot be copied into an unprotected offline note.',
      );
    }
    final now = DateTime.now();
    final title = original.title.isEmpty ? 'Untitled note' : original.title;
    final copy = original.copyWith(
      id: generateUuid(),
      title:
          '${title.length > 184 ? title.substring(0, 184) : title} (conflict copy)',
      version: 0,
      conflictOfNoteId: original.id,
      createdAt: now,
      updatedAt: now,
      labelIds: [],
      isPinned: false,
      isShared: false,
      isOwned: true,
    );
    final change = _QueuedOperation(
      id: generateUuid(),
      kind: 'save',
      payload: {
        'noteId': copy.id,
        'title': copy.title,
        'isNew': true,
        'note': copy.toJson(),
      },
    );
    final originalOperations = _outbox
        .where((item) => item.noteId == original.id)
        .toList();
    _outbox.removeWhere((item) => item.noteId == original.id);
    _outbox.add(change);
    _notes.remove(original.id);
    _notes[copy.id] = copy;
    try {
      await _persist();
    } catch (_) {
      _outbox.remove(change);
      _outbox.addAll(originalOperations);
      _notes.remove(copy.id);
      _notes[original.id] = original;
      rethrow;
    }
    _cursor = 0;
    await synchronize();
    return _notes[copy.id] ?? copy;
  }

  Future<void> retryPending(String operationId) async {
    final operation = _outbox
        .where((item) => item.id == operationId)
        .firstOrNull;
    if (operation == null) return;
    operation.error = null;
    operation.code = null;
    operation.statusCode = null;
    await _persist();
    await synchronize();
  }

  Future<void> watchNote(String? noteId) async {
    if (_watchedNote == noteId) return;
    final previous = _watchedNote;
    _watchedNote = noteId;
    if (_realtimeConnected && previous != null) {
      _sendSocket({'type': 'leave', 'noteId': previous});
    }
    if (_realtimeConnected && noteId != null) {
      _sendSocket({'type': 'join', 'noteId': noteId});
    } else if (noteId != null && _enableRealtime) {
      unawaited(_connectRealtime());
    }
  }

  Future<void> _connectRealtime() async {
    if (_disposed || !_enableRealtime || _connecting || _realtimeConnected) {
      return;
    }
    _connecting = true;
    try {
      final uri = await remote.issueRealtimeConnectionUri();
      if (_disposed) return;
      final socket = WebSocketChannel.connect(uri);
      _socket = socket;
      await socket.ready.timeout(const Duration(seconds: 12));
      if (_disposed) {
        await socket.sink.close();
        return;
      }
      _realtimeConnected = true;
      _reconnectAttempts = 0;
      _socketSubscription = socket.stream.listen(
        _handleRealtime,
        onDone: _socketEnded,
        onError: (Object _) => _socketEnded(),
        cancelOnError: true,
      );
      if (_watchedNote != null) {
        _sendSocket({'type': 'join', 'noteId': _watchedNote});
      }
      _ping?.cancel();
      _ping = Timer.periodic(
        const Duration(seconds: 25),
        (_) => _sendSocket({'type': 'ping'}),
      );
      _publish();
    } catch (error) {
      try {
        await _socket?.sink.close().timeout(const Duration(seconds: 2));
      } catch (_) {
        /* The connection may already have failed. */
      }
      _socket = null;
      if (error is RepositoryException && error.statusCode == 401) {
        _error = 'Your session expired. Sign in again to reconnect.';
        _publish();
      } else {
        _scheduleReconnect();
      }
    } finally {
      _connecting = false;
    }
  }

  void _sendSocket(Map<String, dynamic> message) {
    try {
      _socket?.sink.add(jsonEncode(message));
    } catch (_) {
      _socketEnded();
    }
  }

  void _handleRealtime(dynamic raw) {
    if (_disposed || raw is! String) return;
    try {
      final message = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final id = message['noteId'] as String?;
      final type = message['type'];
      if (type == 'accessRevoked' ||
          (type == 'error' && message['reason'] == 'forbidden')) {
        if (id != null) {
          _notes.remove(id);
          _outbox.removeWhere((operation) => operation.noteId == id);
          _persistInBackground();
        }
      } else if (type == 'permissionChanged' && id != null) {
        final note = _notes[id];
        if (note != null) {
          _notes[id] = note.copyWith(
            canEdit: ['Owner', 'Edit'].contains(message['permission']),
          );
        }
        _persistInBackground();
      }
      _events.add(message);
      if ([
        'noteChanged',
        'permissionChanged',
        'accessRevoked',
      ].contains(type)) {
        unawaited(synchronize());
      }
    } catch (_) {
      /* Ignore malformed transport messages without losing the current draft. */
    }
  }

  void _socketEnded() {
    _realtimeConnected = false;
    _ping?.cancel();
    _socket = null;
    _publish();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || !_enableRealtime) return;
    _reconnect?.cancel();
    final seconds = (1 << (_reconnectAttempts++).clamp(0, 5).toInt())
        .clamp(1, 30)
        .toInt();
    _reconnect = Timer(
      Duration(seconds: seconds),
      () => unawaited(_connectRealtime()),
    );
  }

  /// Stops background work without signing out or deleting the durable outbox.
  Future<void> dispose({bool disposeRemote = true}) async {
    if (_disposed) return;
    _disposed = true;
    _poll?.cancel();
    _ping?.cancel();
    _reconnect?.cancel();
    await _socketSubscription?.cancel();
    try {
      await _socket?.sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Closing must not block sign-out. */
    }
    await _writeTail.catchError((Object _) {});
    await _events.close();
    _status.dispose();
    if (disposeRemote) remote.dispose();
  }

  /// Explicit sign-out clears this account's local notes and queued changes.
  @override
  Future<void> close() async {
    if (_disposed) return;
    await dispose(disposeRemote: false);
    await _store.remove(storageKey);
    _notes.clear();
    _labels.clear();
    _outbox.clear();
    _volatileProtectedDrafts.clear();
    await remote.close();
  }
}

class _QueuedOperation {
  _QueuedOperation({
    required this.id,
    required this.kind,
    required this.payload,
    this.error,
    this.code,
    this.statusCode,
  });
  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  String? error;
  String? code;
  int? statusCode;
  String? get noteId => payload['noteId'] as String?;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'payload': payload,
    'error': error,
    'code': code,
    'statusCode': statusCode,
  };
  factory _QueuedOperation.fromJson(Map<String, dynamic> data) =>
      _QueuedOperation(
        id: data['id'] as String,
        kind: data['kind'] as String,
        payload: Map<String, dynamic>.from(data['payload'] as Map),
        error: data['error'] as String?,
        code: data['code'] as String?,
        statusCode: data['statusCode'] as int?,
      );
}
