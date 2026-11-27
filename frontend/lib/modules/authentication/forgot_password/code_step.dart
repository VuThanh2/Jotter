import 'package:flutter/material.dart';
import 'package:jotter/shared/widgets/otp_input.dart';

class CodeStep extends StatefulWidget {
  const CodeStep({
    super.key,
    required this.busy,
    required this.onSubmit,
    required this.onResend,
    required this.onChangeEmail,
  });

  final bool busy;
  final ValueChanged<String> onSubmit;
  final Future<int> Function() onResend;
  final VoidCallback onChangeEmail;

  @override
  State<CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<CodeStep> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.busy && _form.currentState!.validate()) {
      widget.onSubmit(_code.text);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OtpInput(
          key: const Key('reset-code'),
          controller: _code,
          onCompleted: (_) => _submit(),
        ),
        Row(
          children: [
            TextButton(
              onPressed: widget.busy ? null : widget.onChangeEmail,
              child: const Text('Use another email'),
            ),
            const Spacer(),
            ResendCodeButton(
              onResend: widget.onResend,
              onSent: _code.clear,
              initialCooldown: 60,
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.busy ? null : _submit,
          child: const Text('Verify code'),
        ),
      ],
    ),
  );
}
