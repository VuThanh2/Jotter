import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_state.dart';

/// Pending changes and the actions that resolve them.
class SyncSheetCubit extends Cubit<SyncSheetState> {
  SyncSheetCubit(this._workspace)
    : super(
        SyncSheetState(
          status: _workspace.syncStatus.value,
          changes: _workspace.pendingChanges,
        ),
      ) {
    _workspace.syncStatus.addListener(_refresh);
  }

  final OfflineNoteRepository _workspace;

  JotterNote? draftOf(String changeId) => _workspace.pendingDraft(changeId);

  Future<void> syncNow() => _run(_workspace.synchronize);

  Future<void> retry(String changeId) =>
      _run(() => _workspace.retryPending(changeId));

  Future<void> saveAsCopy(String changeId) =>
      _run(() => _workspace.recoverConflictAsCopy(changeId));

  Future<void> discard(String changeId) =>
      _run(() => _workspace.discardPending(changeId));

  void _refresh() {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: _workspace.syncStatus.value,
        changes: _workspace.pendingChanges,
        busy: state.busy,
        error: state.error,
      ),
    );
  }

  Future<void> _run(Future<Object?> Function() action) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await action();
      if (!isClosed) emit(state.copyWith(busy: false));
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            error: error is RepositoryException
                ? error.message
                : 'That did not work. Please try again.',
          ),
        );
      }
    }
    _refresh();
  }

  @override
  Future<void> close() {
    _workspace.syncStatus.removeListener(_refresh);
    return super.close();
  }
}
