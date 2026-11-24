import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/modules/authentication/activation/activation_api.dart';
import 'package:jotter/modules/authentication/activation/activation_state.dart';
import 'package:jotter/modules/authentication/shared/auth_api.dart';

class ActivationCubit extends Cubit<ActivationState> {
  ActivationCubit(this._api) : super(const ActivationState());

  final ActivationApi _api;

  String get email => _api.email;

  Future<void> confirm(String code) async {
    if (state.isSubmitting) return;
    emit(const ActivationState.submitting());
    try {
      final account = await _api.confirm(code);
      if (!isClosed) emit(ActivationState.success(account));
    } catch (error) {
      if (!isClosed) emit(ActivationState.failure(authErrorMessage(error)));
    }
  }

  Future<int> resend() async {
    try {
      final cooldown = await _api.resend();
      // A fresh code makes any earlier "wrong/expired code" message stale.
      if (!isClosed) emit(const ActivationState());
      return cooldown;
    } catch (error) {
      emit(ActivationState.failure(authErrorMessage(error)));
      return 0;
    }
  }
}
