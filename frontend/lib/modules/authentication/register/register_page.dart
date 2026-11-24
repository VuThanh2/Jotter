import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/modules/authentication/register/register_cubit.dart';
import 'package:jotter/modules/authentication/register/register_state.dart';
import 'package:jotter/modules/authentication/shared/auth_api.dart';
import 'package:jotter/modules/authentication/shared/auth_layout.dart';
import 'package:jotter/modules/authentication/shared/auth_models.dart';
import 'package:jotter/shared/lib/session.dart';
import 'package:jotter/shared/models/submit_state.dart';
import 'package:jotter/shared/widgets/password_field.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key, this.authApi});

  final AuthApi? authApi;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RegisterCubit(authApi ?? AuthApi()),
    child: const _RegisterView(),
  );
}

class _RegisterView extends StatefulWidget {
  const _RegisterView();

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_email, _name, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    context.read<RegisterCubit>().submit(
      email: _email.text,
      displayName: _name.text,
      password: _password.text,
      confirmPassword: _confirm.text,
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<RegisterCubit, RegisterState>(
        listener: (context, state) {
          if (state.isSuccess) {
            context.read<SessionCubit>().signIn(state.result!);
          }
        },
        builder: (context, state) {
          final busy = state.isSubmitting || state.isSuccess;
          return AuthLayout(
            title: 'Create your account',
            subtitle:
                'Start writing right away. We will email you a code to '
                'confirm your address.',
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('register-email'),
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
                  TextFormField(
                    key: const Key('register-name'),
                    controller: _name,
                    enabled: !busy,
                    maxLength: 100,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      counterText: '',
                    ),
                    validator: (value) =>
                        validateRequired(value, 'your display name'),
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    key: const Key('register-password'),
                    controller: _password,
                    label: 'Password',
                    enabled: !busy,
                    newPassword: true,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    key: const Key('register-confirm'),
                    controller: _confirm,
                    label: 'Confirm password',
                    enabled: !busy,
                    newPassword: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: validateConfirmation(() => _password.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    passwordHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.jotterColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (state.status == SubmitStatus.failure) ...[
                    MessageStrip(state.error!, error: true),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    key: const Key('register-submit'),
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => context.go(AppRoutes.login),
                        child: const Text('Sign in'),
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
