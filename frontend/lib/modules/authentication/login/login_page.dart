import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/modules/authentication/login/login_cubit.dart';
import 'package:jotter/modules/authentication/login/login_state.dart';
import 'package:jotter/modules/authentication/shared/auth_api.dart';
import 'package:jotter/modules/authentication/shared/auth_layout.dart';
import 'package:jotter/modules/authentication/shared/auth_models.dart';
import 'package:jotter/shared/lib/session.dart';
import 'package:jotter/shared/models/submit_state.dart';
import 'package:jotter/shared/widgets/password_field.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.passwordReset = false, this.authApi});

  final bool passwordReset;
  final AuthApi? authApi;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LoginCubit(authApi ?? AuthApi()),
    child: _LoginView(passwordReset: passwordReset),
  );
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.passwordReset});

  final bool passwordReset;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    context.read<LoginCubit>().submit(
      email: _email.text,
      password: _password.text,
    );
  }

  String? get _notice {
    if (widget.passwordReset) {
      return 'Password updated. Sign in with your new password.';
    }
    final session = context.watch<SessionCubit>().state;
    return session is SessionSignedOut ? session.notice : null;
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<LoginCubit, LoginState>(
    listener: (context, state) {
      if (state.isSuccess) {
        context.read<SessionCubit>().signIn(state.result!);
      }
    },
    builder: (context, state) {
      final busy = state.isSubmitting || state.isSuccess;
      final notice = _notice;
      return AuthLayout(
        title: 'Welcome back',
        subtitle: 'Sign in to pick up where you left off.',
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notice != null) ...[
                MessageStrip(notice),
                const SizedBox(height: 20),
              ],
              TextFormField(
                key: const Key('login-email'),
                controller: _email,
                enabled: !busy,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('login-password'),
                controller: _password,
                label: 'Password',
                enabled: !busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password.'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => context.go(AppRoutes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (state.status == SubmitStatus.failure) ...[
                MessageStrip(state.error!, error: true),
                const SizedBox(height: 16),
              ],
              FilledButton(
                key: const Key('login-submit'),
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('New to Jotter?'),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => context.go(AppRoutes.register),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
