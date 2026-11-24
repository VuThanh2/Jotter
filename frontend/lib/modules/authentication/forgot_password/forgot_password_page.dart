import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/modules/authentication/forgot_password/code_step.dart';
import 'package:jotter/modules/authentication/forgot_password/email_step.dart';
import 'package:jotter/modules/authentication/forgot_password/forgot_password_api.dart';
import 'package:jotter/modules/authentication/forgot_password/forgot_password_cubit.dart';
import 'package:jotter/modules/authentication/forgot_password/forgot_password_state.dart';
import 'package:jotter/modules/authentication/forgot_password/new_password_step.dart';
import 'package:jotter/modules/authentication/shared/auth_layout.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key, this.api});

  final ForgotPasswordApi? api;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ForgotPasswordCubit(api ?? ForgotPasswordApi()),
    child: BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
      listenWhen: (previous, current) => current.step == ResetStep.done,
      listener: (context, _) => context.go(
        Uri(path: AppRoutes.login, queryParameters: {'reset': '1'}).toString(),
      ),
      builder: (context, state) {
        final cubit = context.read<ForgotPasswordCubit>();
        final (title, subtitle) = switch (state.step) {
          ResetStep.email => (
            'Reset your password',
            'Enter your account email and we will send you a six-digit code.',
          ),
          ResetStep.code => (
            'Check your email',
            'If an account exists for ${state.email}, a code is on its way.',
          ),
          _ => (
            'Choose a new password',
            'You will sign in with it on every device.',
          ),
        };
        return AuthLayout(
          title: title,
          subtitle: subtitle,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: state.busy ? null : () => context.go(AppRoutes.login),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to sign in'),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.error != null) ...[
                MessageStrip(state.error!, error: true),
                const SizedBox(height: 16),
              ],
              switch (state.step) {
                ResetStep.email => EmailStep(
                  initialEmail: state.email,
                  busy: state.busy,
                  onSubmit: cubit.requestCode,
                ),
                ResetStep.code => CodeStep(
                  busy: state.busy,
                  onSubmit: cubit.verifyCode,
                  onResend: cubit.resendCode,
                  onChangeEmail: cubit.startOver,
                ),
                _ => NewPasswordStep(
                  busy: state.busy,
                  onSubmit: cubit.resetPassword,
                ),
              },
            ],
          ),
        );
      },
    ),
  );
}
