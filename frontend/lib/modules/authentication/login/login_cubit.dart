import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/modules/authentication/login/login_state.dart';
import 'package:jotter/modules/authentication/shared/auth_api.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._api) : super(const LoginState());

  final AuthApi _api;

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;
    emit(const LoginState.submitting());
    try {
      final remote = await _api.signIn(email.trim(), password);
      if (!isClosed) emit(LoginState.success(remote));
    } catch (error) {
      if (!isClosed) emit(LoginState.failure(authErrorMessage(error)));
    }
  }
}
