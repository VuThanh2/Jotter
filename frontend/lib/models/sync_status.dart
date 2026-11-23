import 'package:flutter/foundation.dart';

@immutable
class WorkspaceSyncStatus {
  const WorkspaceSyncStatus({
    this.pendingCount = 0,
    this.conflictCount = 0,
    this.isSyncing = false,
    this.isOffline = false,
    this.realtimeConnected = false,
    this.lastSyncedAt,
    this.error,
  });

  final int pendingCount;
  final int conflictCount;
  final bool isSyncing;
  final bool isOffline;
  final bool realtimeConnected;
  final DateTime? lastSyncedAt;
  final String? error;

  String get label {
    if (conflictCount > 0)
      return '$conflictCount change${conflictCount == 1 ? '' : 's'} need attention';
    if (isSyncing) return 'Syncing…';
    if (isOffline)
      return pendingCount > 0
          ? 'Offline · $pendingCount pending'
          : 'Offline · saved on this device';
    if (pendingCount > 0)
      return '$pendingCount pending change${pendingCount == 1 ? '' : 's'}';
    return lastSyncedAt == null ? 'Ready to sync' : 'All changes saved';
  }
}

@immutable
class PendingWorkspaceChange {
  const PendingWorkspaceChange({
    required this.id,
    required this.kind,
    required this.title,
    this.noteId,
    this.error,
    this.code,
  });
  final String id;
  final String kind;
  final String title;
  final String? noteId;
  final String? error;
  final String? code;
  bool get isBlocked => error != null;
  bool get isConflict => code == 'VersionConflict' || code == 'IdAlreadyExists';
}
