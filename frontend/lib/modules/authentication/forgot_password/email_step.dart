import 'package:flutter/material.dart';
import 'package:jotter/modules/authentication/shared/auth_models.dart';

class EmailStep extends StatefulWidget {
  const EmailStep({
    super.key,
    required this.initialEmail,
    required this.busy,
    required this.onSubmit,
  });

  final String initialEmail;
  final bool busy;
  final ValueChanged<String> onSubmit;

  @override
  State<EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends State<EmailStep> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) widget.onSubmit(_email.text);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('reset-email'),
          controller: _email,
          enabled: !widget.busy,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: 'Email'),
          validator: validateEmail,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: widget.busy ? null : _submit,
          child: const Text('Send code'),
        ),
      ],
    ),
  );
}
