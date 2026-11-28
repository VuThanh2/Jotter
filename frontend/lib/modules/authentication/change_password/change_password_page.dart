import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/modules/authentication/change_password/change_password_api.dart';
import 'package:jotter/modules/authentication/change_password/change_password_cubit.dart';
import 'package:jotter/modules/authentication/change_password/change_password_state.dart';
import 'package:jotter/modules/authentication/shared/auth_models.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/shared/models/submit_state.dart';
import 'package:jotter/shared/widgets/page_frame.dart';
import 'package:jotter/shared/widgets/password_field.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ChangePasswordCubit(
      ChangePasswordApi(context.read<ApiNoteRepository>()),
    ),
    child: const _ChangePasswordView(),
  );
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_current, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    context.read<ChangePasswordCubit>().submit(
      current: _current.text,
      password: _password.text,
      confirm: _confirm.text,
    );
  }

  void _onResult(BuildContext context, ChangePasswordState state) {
    if (!state.isSuccess) return;
    _form.currentState!.reset();
    for (final controller in [_current, _password, _confirm]) {
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    banner: const UnverifiedBanner(),
    title: 'Change password',
    subtitle: 'Keep your account safe with a password only you know.',
    icon: Icons.lock_outline_rounded,
    fallbackRoute: AppRoutes.account,
    maxWidth: 440,
    cardOnWide: true,
    aside: const PageIntro(
      heading: 'A fresh password',
      body: 'Other devices will be signed out. This one stays signed in.',
      points: [
        (Icons.password_rounded, 'Use a mix of letters, numbers and symbols.'),
        (Icons.devices_rounded, 'Sign in again on your other devices after.'),
        (Icons.key_off_rounded, 'Note passwords are not changed by this.'),
      ],
    ),
    child: BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listener: _onResult,
      builder: (context, state) {
        final busy = state.isSubmitting;
        return AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!context.isExpanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Other devices will be signed out. This one stays signed '
                    'in.',
                    style: TextStyle(color: context.jotterColors.muted),
                  ),
                  const SizedBox(height: 24),
                ],
                PasswordField(
                  key: const Key('current-password'),
                  controller: _current,
                  label: 'Current password',
                  enabled: !busy,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('new-password'),
                  controller: _password,
                  label: 'New password',
                  enabled: !busy,
                  newPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a new password.';
                    }
                    return value == _current.text
                        ? 'Choose a password you have not used here.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('confirm-new-password'),
                  controller: _confirm,
                  label: 'Confirm new password',
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
                    fontSize: 12.5,
                    color: context.jotterColors.muted,
                  ),
                ),
                const SizedBox(height: 20),
                if (state.status == SubmitStatus.failure) ...[
                  MessageStrip(state.error!, error: true),
                  const SizedBox(height: 16),
                ],
                if (state.isSuccess) ...[
                  const MessageStrip(
                    'Password changed. Other devices need to sign in again.',
                    tone: JotterTone.success,
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  key: const Key('change-password-submit'),
                  onPressed: busy ? null : _submit,
                  child: Text(busy ? 'Saving…' : 'Change password'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
