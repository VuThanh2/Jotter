import 'package:jotter/data/account_api.dart';
import 'package:jotter/shared/lib/config.dart';

class ForgotPasswordApi {
  ForgotPasswordApi({this.baseUrl = AppConfig.apiBaseUrl});

  final String baseUrl;

  Future<void> requestCode(String email) =>
      _call((api) => api.forgotPassword(email));

  /// Returns the reset ticket that authorises choosing a new password.
  Future<String> verifyCode(String email, String code) =>
      _call((api) => api.verifyResetCode(email, code));

  Future<void> resetPassword(String ticket, String password, String confirm) =>
      _call((api) => api.resetPassword(ticket, password, confirm));

  Future<T> _call<T>(Future<T> Function(AccountAuthApi api) call) async {
    final api = AccountAuthApi(baseUrl);
    try {
      return await call(api);
    } finally {
      api.close();
    }
  }
}
