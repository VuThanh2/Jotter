import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/modules/authentication/shared/auth_models.dart';
import 'package:jotter/shared/widgets/password_field.dart';

class NewPasswordStep extends StatefulWidget {
  const NewPasswordStep({
    super.key,
    required this.busy,
    required this.onSubmit,
  });

  final bool busy;
  final void Function(String password, String confirm) onSubmit;

  @override
  State<NewPasswordStep> createState() => _NewPasswordStepState();
}

class _NewPasswordStepState extends State<NewPasswordStep> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      widget.onSubmit(_password.text, _confirm.text);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PasswordField(
          key: const Key('reset-password'),
          controller: _password,
          label: 'New password',
          enabled: !widget.busy,
          autofocus: true,
          newPassword: true,
        ),
        const SizedBox(height: 16),
        PasswordField(
          key: const Key('reset-confirm'),
          controller: _confirm,
          label: 'Confirm new password',
          enabled: !widget.busy,
          newPassword: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          validator: validateConfirmation(() => _password.text),
        ),
        const SizedBox(height: 8),
        Text(
          passwordHint,
          style: TextStyle(fontSize: 12.5, color: context.jotterColors.muted),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: widget.busy ? null : _submit,
          child: const Text('Save new password'),
        ),
      ],
    ),
  );
}
