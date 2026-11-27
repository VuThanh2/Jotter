import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/modules/protection/manage_protection/manage_protection_state.dart';
import 'package:jotter/modules/protection/manage_protection/protection_api.dart';

/// Each action returns whether it succeeded; failures stay in [state.error]
/// so the open password dialog can show them.
class ManageProtectionCubit extends Cubit<ManageProtectionState> {
  ManageProtectionCubit(this._api, {required this.noteId})
    : super(const ManageProtectionState());

  final ProtectionApi _api;
  final String noteId;

  Future<bool> enable(String password, String confirmation) =>
      _run(() => _api.enable(noteId, password, confirmation));

  Future<bool> changePassword(
    String current,
    String password,
    String confirmation,
  ) => _run(() => _api.changePassword(noteId, current, password, confirmation));

  Future<bool> disable(String current) =>
      _run(() => _api.disable(noteId, current));

  Future<bool> lock() => _run(() => _api.lock(noteId));

  void clearError() => emit(const ManageProtectionState());

  Future<bool> _run(Future<void> Function() action) async {
    if (state.busy) return false;
    emit(const ManageProtectionState(busy: true));
    try {
      await action();
      if (!isClosed) emit(const ManageProtectionState());
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          ManageProtectionState(
            error: error is RepositoryException
                ? error.message
                : 'That did not work. Please try again.',
          ),
        );
      }
      return false;
    }
  }
}
