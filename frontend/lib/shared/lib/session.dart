import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jotter/data/account_api.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/models/jotter_account.dart';

class StoredSession {
  const StoredSession({
    required this.baseUrl,
    required this.accessToken,
    required this.account,
  });

  factory StoredSession.fromJson(Map<String, dynamic> json) => StoredSession(
    baseUrl: json['baseUrl'] as String,
    accessToken: json['accessToken'] as String,
    account: JotterAccount.fromJson(
      Map<String, dynamic>.from(json['account'] as Map),
    ),
  );

  factory StoredSession.of(ApiNoteRepository remote) => StoredSession(
    baseUrl: remote.baseUrl,
    accessToken: remote.accessToken,
    account: remote.account,
  );

  final String baseUrl;
  final String accessToken;
  final JotterAccount account;

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'accessToken': accessToken,
    'account': account.toJson(),
  };
}

abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'jotter.session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return StoredSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupted entry must not lock the user out of the login screen.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

class MemorySessionStore implements SessionStore {
  StoredSession? value;

  @override
  Future<StoredSession?> read() async => value;

  @override
  Future<void> write(StoredSession session) async => value = session;

  @override
  Future<void> clear() async => value = null;
}

sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

final class SessionRestoring extends SessionState {
  const SessionRestoring();
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.notice, this.resumeLocation = true});

  final String? notice;

  /// False after an explicit sign-out, so the next user starts fresh.
  final bool resumeLocation;

  @override
  List<Object?> get props => [notice, resumeLocation];
}

final class SessionActive extends SessionState {
  const SessionActive(this.workspace);

  final OfflineNoteRepository workspace;

  ApiNoteRepository get remote => workspace.remote;

  @override
  List<Object?> get props => [workspace];
}

typedef WorkspaceOpener =
    Future<OfflineNoteRepository> Function(ApiNoteRepository remote);

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._store, {WorkspaceOpener? openWorkspace})
    : _openWorkspace = openWorkspace ?? OfflineNoteRepository.open,
      super(const SessionRestoring());

  static const expiredNotice = 'Your session has ended. Please sign in again.';

  final SessionStore _store;
  final WorkspaceOpener _openWorkspace;

  OfflineNoteRepository? get workspace => switch (state) {
    SessionActive(:final workspace) => workspace,
    _ => null,
  };

  Future<void> restore() async {
    final stored = await _store.read();
    if (stored == null) {
      emit(const SessionSignedOut());
      return;
    }
    final ApiNoteRepository remote;
    try {
      remote = ApiNoteRepository.restore(
        baseUrl: stored.baseUrl,
        accessToken: stored.accessToken,
        account: stored.account,
      );
    } on RepositoryException {
      await _store.clear();
      emit(const SessionSignedOut());
      return;
    }
    try {
      await remote.getProfile();
    } on RepositoryException catch (error) {
      if (error.statusCode == 401) {
        remote.dispose();
        await _store.clear();
        emit(const SessionSignedOut(notice: expiredNotice));
        return;
      }
      // Offline: keep the cached account and open the local workspace.
    }
    await _activate(remote);
  }

  Future<void> signIn(ApiNoteRepository remote) => _activate(remote);

  /// Persists account changes (name, avatar, activation) for the next start.
  Future<void> accountChanged() async {
    final remote = workspace?.remote;
    if (remote != null) await _store.write(StoredSession.of(remote));
  }

  Future<void> signOut() async {
    final current = workspace;
    emit(const SessionSignedOut(resumeLocation: false));
    await _store.clear();
    await current?.close();
  }

  Future<void> _activate(ApiNoteRepository remote) async {
    remote.onAccessTokenChanged = (_) => accountChanged();
    remote.onUnauthorized = _expire;
    final workspace = await _openWorkspace(remote);
    await _store.write(StoredSession.of(remote));
    if (isClosed) {
      await workspace.dispose();
      return;
    }
    emit(SessionActive(workspace));
  }

  /// Keeps the local cache so the same account finds its offline drafts again.
  void _expire() {
    final current = workspace;
    if (current == null) return;
    emit(const SessionSignedOut(notice: expiredNotice));
    _store.clear();
    current.dispose();
  }

  @override
  Future<void> close() async {
    await workspace?.dispose();
    return super.close();
  }
}
