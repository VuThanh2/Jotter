import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/modules/authentication/register/register_state.dart';
import 'package:jotter/modules/authentication/shared/auth_api.dart';

class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(this._api) : super(const RegisterState());

  final AuthApi _api;

  Future<void> submit({
    required String email,
    required String displayName,
    required String password,
    required String confirmPassword,
  }) async {
    if (state.isSubmitting) return;
    emit(const RegisterState.submitting());
    try {
      final remote = await _api.register(
        email: email,
        displayName: displayName,
        password: password,
        confirmPassword: confirmPassword,
      );
      if (!isClosed) emit(RegisterState.success(remote));
    } catch (error) {
      if (!isClosed) emit(RegisterState.failure(authErrorMessage(error)));
    }
  }
}
