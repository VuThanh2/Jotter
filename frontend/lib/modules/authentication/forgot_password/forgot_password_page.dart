import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
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
              _StepProgress(step: state.step),
              const SizedBox(height: 22),
              // Each step slides in from the right as the reset moves on.
              AnimatedSwitcher(
                duration: JotterMotion.medium,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(state.step),
                  child: switch (state.step) {
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
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Three short bars that fill as the reset moves from email to code to the
/// new password.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});

  final ResetStep step;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final current = switch (step) {
      ResetStep.email => 0,
      ResetStep.code => 1,
      _ => 2,
    };
    return Semantics(
      label: 'Step ${current + 1} of 3',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: JotterMotion.medium,
                curve: JotterMotion.curve,
                height: 4,
                decoration: BoxDecoration(
                  color: index <= current
                      ? palette.accent
                      : palette.ink.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
