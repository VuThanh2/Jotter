import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInput extends StatelessWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.label = 'Six-digit code',
    this.autofocus = true,
    this.onCompleted,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) => TextFormField(
    // Never locked while a code is checked (the cubits ignore repeats), so a
    // rejected code can be corrected without clicking back in.
    controller: controller,
    autofocus: autofocus,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    style: const TextStyle(fontSize: 20, letterSpacing: 8),
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    onChanged: (value) {
      if (value.length == 6) onCompleted?.call(value);
    },
    onFieldSubmitted: onCompleted,
    validator: (value) =>
        value?.length == 6 ? null : 'Enter the six-digit code.',
    decoration: InputDecoration(labelText: label, counterText: ''),
  );
}

/// A resend button that stays disabled while its cooldown runs.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.onResend,
    this.initialCooldown = 0,
    this.label = 'Resend code',
    this.onSent,
  });

  /// Returns the cooldown in seconds before the next resend is allowed.
  final Future<int> Function() onResend;
  final int initialCooldown;
  final String label;

  /// Runs after a new code was sent, e.g. to clear the stale code field.
  final VoidCallback? onSent;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  int _seconds = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _start(widget.initialCooldown);
  }

  void _start(int seconds) {
    _timer?.cancel();
    setState(() => _seconds = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) timer.cancel();
      if (mounted) setState(() => _seconds--);
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      final cooldown = await widget.onResend();
      _start(cooldown);
      if (cooldown > 0 && mounted) {
        widget.onSent?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code is on its way.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: _seconds > 0 || _sending ? null : _resend,
    child: Text(
      _seconds > 0 ? '${widget.label} in ${_seconds}s' : widget.label,
    ),
  );
}
