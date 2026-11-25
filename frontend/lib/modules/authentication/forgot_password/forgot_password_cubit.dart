import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/modules/authentication/forgot_password/forgot_password_api.dart';
import 'package:jotter/modules/authentication/forgot_password/forgot_password_state.dart';
import 'package:jotter/modules/authentication/shared/auth_api.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit(this._api) : super(const ForgotPasswordState());

  static const resendCooldownSeconds = 60;

  final ForgotPasswordApi _api;

  Future<void> requestCode(String email) => _run(() async {
    await _api.requestCode(email.trim());
    emit(state.copyWith(step: ResetStep.code, email: email.trim()));
  });

  Future<int> resendCode() async {
    try {
      await _api.requestCode(state.email);
      // A fresh code makes any earlier "wrong/expired code" message stale.
      emit(state.copyWith());
      return resendCooldownSeconds;
    } catch (error) {
      emit(state.copyWith(error: authErrorMessage(error)));
      return 0;
    }
  }

  Future<void> verifyCode(String code) => _run(() async {
    final ticket = await _api.verifyCode(state.email, code);
    emit(state.copyWith(step: ResetStep.newPassword, ticket: ticket));
  });

  Future<void> resetPassword(String password, String confirm) => _run(() async {
    try {
      await _api.resetPassword(state.ticket!, password, confirm);
      emit(state.copyWith(step: ResetStep.done));
    } on RepositoryException catch (error) {
      // An expired ticket cannot be reused, so a fresh code is needed.
      if (const {'InvalidResetTicket', 'TicketExpired'}.contains(error.code)) {
        emit(
          ForgotPasswordState(
            email: state.email,
            error: 'This reset link expired. Request a new code.',
          ),
        );
        return;
      }
      rethrow;
    }
  });

  void startOver() => emit(ForgotPasswordState(email: state.email));

  Future<void> _run(Future<void> Function() action) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await action();
      if (!isClosed) emit(state.copyWith(busy: false));
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: authErrorMessage(error)));
      }
    }
  }
}
