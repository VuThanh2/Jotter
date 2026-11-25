import 'package:jotter/data/account_api.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/shared/lib/config.dart';

class AuthApi {
  AuthApi({this.baseUrl = AppConfig.apiBaseUrl});

  final String baseUrl;

  Future<ApiNoteRepository> signIn(String email, String password) =>
      ApiNoteRepository.signIn(
        baseUrl: baseUrl,
        email: email,
        password: password,
      );

  Future<ApiNoteRepository> register({
    required String email,
    required String displayName,
    required String password,
    required String confirmPassword,
  }) => _anonymous(
    (api) => api.register(
      email: email,
      displayName: displayName,
      password: password,
      confirmPassword: confirmPassword,
    ),
  );

  Future<T> _anonymous<T>(Future<T> Function(AccountAuthApi api) call) async {
    final api = AccountAuthApi(baseUrl);
    try {
      return await call(api);
    } finally {
      api.close();
    }
  }
}

/// Turns API failures into one readable sentence per problem.
String authErrorMessage(Object error) {
  if (error is RepositoryException && error.code == 'InvalidCredentials') {
    return 'Incorrect email or password.';
  }
  return accountErrorMessage(error);
}
