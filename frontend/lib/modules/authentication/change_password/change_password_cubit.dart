import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/modules/authentication/change_password/change_password_api.dart';
import 'package:jotter/modules/authentication/change_password/change_password_state.dart';
import 'package:jotter/modules/authentication/shared/auth_api.dart';

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit(this._api) : super(const ChangePasswordState());

  final ChangePasswordApi _api;

  Future<void> submit({
    required String current,
    required String password,
    required String confirm,
  }) async {
    if (state.isSubmitting) return;
    emit(const ChangePasswordState.submitting());
    try {
      await _api.change(current: current, password: password, confirm: confirm);
      if (!isClosed) emit(const ChangePasswordState.success());
    } catch (error) {
      if (!isClosed) emit(ChangePasswordState.failure(authErrorMessage(error)));
    }
  }
}
