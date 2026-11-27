import 'package:equatable/equatable.dart';
import 'package:jotter/models/sync_status.dart';

class SyncSheetState extends Equatable {
  const SyncSheetState({
    required this.status,
    this.changes = const [],
    this.busy = false,
    this.error,
  });

  final WorkspaceSyncStatus status;
  final List<PendingWorkspaceChange> changes;
  final bool busy;
  final String? error;

  SyncSheetState copyWith({
    WorkspaceSyncStatus? status,
    List<PendingWorkspaceChange>? changes,
    bool? busy,
    String? error,
  }) => SyncSheetState(
    status: status ?? this.status,
    changes: changes ?? this.changes,
    busy: busy ?? this.busy,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    [for (final change in changes) '${change.id}:${change.error}'],
    busy,
    error,
  ];
}
