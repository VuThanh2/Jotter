import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account_api.dart';
import '../data/api_note_repository.dart';
import '../data/note_repository.dart';

Future<ApiNoteRepository?> showAccountDialog(BuildContext context) =>
    showDialog<ApiNoteRepository>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AccountDialog(),
    );

Future<bool?> showActivationDialog(
  BuildContext context, {
  required ApiNoteRepository repository,
  int initialCooldown = 0,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ActivationDialog(
    repository: repository,
    initialCooldown: initialCooldown,
  ),
);

enum _AccountStep { signIn, register, forgot, verify, reset }

class _AccountDialog extends StatefulWidget {
  const _AccountDialog();
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  var _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _baseUrl = TextEditingController(text: defaultApiUrl);
  _AccountStep _step = _AccountStep.signIn;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;
  String? _resetTicket;
  String? _resetBaseUrl;
  int _resendSeconds = 0;
  Timer? _cooldown;

  @override
  void dispose() {
    _cooldown?.cancel();
    for (final input in [_email, _password, _confirm, _name, _code, _baseUrl]) {
      input.dispose();
    }
    super.dispose();
  }

  String get _heading => switch (_step) {
    _AccountStep.signIn => 'Your notes, together.',
    _AccountStep.register => 'Make room for your ideas.',
    _AccountStep.forgot => 'Find your way back.',
    _AccountStep.verify => 'Check your email.',
    _AccountStep.reset => 'A fresh start.',
  };
  String get _action => switch (_step) {
    _AccountStep.signIn => 'Sign in',
    _AccountStep.register => 'Create account',
    _AccountStep.forgot => 'Send reset code',
    _AccountStep.verify => 'Verify reset code',
    _AccountStep.reset => 'Reset password',
  };
  String get _description => switch (_step) {
    _AccountStep.signIn => 'Sign in to your Jotter account to open and save your notes across devices.',
    _AccountStep.register =>
      'Create an account, then confirm the code sent to your email.',
    _AccountStep.forgot => 'Enter your email. If an account exists, we will send a password reset code.',
    _AccountStep.verify =>
      'Enter the six-digit reset code sent to ${_email.text.trim()}.',
    _AccountStep.reset => 'Choose a new password for your account. You will sign in after resetting it.',
  };

  void _go(_AccountStep step) {
    setState(() {
      _step = step;
      _error = null;
      _notice = null;
      _formKey = GlobalKey<FormState>();
    });
  }

  void _startCooldown(int seconds) {
    _cooldown?.cancel();
    _resendSeconds = seconds;
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    AccountAuthApi? api;
    try {
      if (_step == _AccountStep.signIn || _step == _AccountStep.register) {
        ApiNoteRepository repository;
        if (_step == _AccountStep.signIn) {
          repository = await ApiNoteRepository.signIn(
            baseUrl: _baseUrl.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
        } else {
          api = AccountAuthApi(_baseUrl.text);
          repository = await api.register(
            email: _email.text,
            displayName: _name.text,
            password: _password.text,
            confirmPassword: _confirm.text,
          );
        }
        if (!mounted) {
          await repository.close();
          return;
        }
        if (!repository.account.isActivated) {
          await showActivationDialog(
            context,
            repository: repository,
            initialCooldown: _step == _AccountStep.register ? 60 : 0,
          );
        }
        if (!mounted) {
          await repository.close();
          return;
        }
        TextInput.finishAutofillContext();
        Navigator.of(context).pop(repository);
        return;
      }
      api = AccountAuthApi(_resetBaseUrl ?? _baseUrl.text);
      if (_step == _AccountStep.forgot) {
        await api.forgotPassword(_email.text);
        if (!mounted) return;
        setState(() {
          _resetBaseUrl = _baseUrl.text.trim();
          _step = _AccountStep.verify;
          _notice = 'If that account exists, a reset code has been sent.';
          _code.clear();
        });
        _startCooldown(60);
      } else if (_step == _AccountStep.verify) {
        final ticket = await api.verifyResetCode(_email.text, _code.text);
        if (!mounted) return;
        setState(() {
          _resetTicket = ticket;
          _step = _AccountStep.reset;
          _password.clear();
          _confirm.clear();
        });
      } else {
        await api.resetPassword(_resetTicket!, _password.text, _confirm.text);
        if (!mounted) return;
        setState(() {
          _step = _AccountStep.signIn;
          _resetTicket = null;
          _password.clear();
          _confirm.clear();
          _notice =
              'Password reset. You can now sign in with your new password.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = accountErrorMessage(error));
    } finally {
      api?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendReset() async {
    if (_busy || _resendSeconds > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    AccountAuthApi? api;
    try {
      api = AccountAuthApi(_resetBaseUrl ?? _baseUrl.text);
      await api.forgotPassword(_email.text);
      if (!mounted) return;
      setState(
        () => _notice = 'If that account exists, a new code has been sent.',
      );
      _startCooldown(60);
    } catch (error) {
      if (mounted) setState(() => _error = accountErrorMessage(error));
    } finally {
      api?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, {Widget? suffix}) =>
      InputDecoration(labelText: label, suffixIcon: suffix);
  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Enter $label.' : null;
  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'Enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()))
      return 'Enter a valid email address.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final login = _step == _AccountStep.signIn;
    final register = _step == _AccountStep.register;
    final credentials = login || register || _step == _AccountStep.reset;
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          size: 36,
                          color: Color(0xFFB75032),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close sign in',
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _heading,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _description,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    if (login || register || _step == _AccountStep.forgot) ...[
                      TextFormField(
                        key: const Key('account-email'),
                        controller: _email,
                        enabled: !_busy,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        autocorrect: false,
                        decoration: _decoration('Email address'),
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (register) ...[
                      TextFormField(
                        key: const Key('account-name'),
                        controller: _name,
                        enabled: !_busy,
                        maxLength: 100,
                        decoration: _decoration('Display name'),
                        validator: (value) =>
                            _required(value, 'your display name'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (credentials) ...[
                      TextFormField(
                        key: const Key('account-password'),
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [
                          login
                              ? AutofillHints.password
                              : AutofillHints.newPassword,
                        ],
                        textInputAction: login
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onFieldSubmitted: login ? (_) => _submit() : null,
                        decoration: _decoration(
                          _step == _AccountStep.reset
                              ? 'New password'
                              : 'Password',
                          suffix: IconButton(
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (register || _step == _AccountStep.reset) ...[
                      TextFormField(
                        key: const Key('account-confirm'),
                        controller: _confirm,
                        enabled: !_busy,
                        obscureText: _obscure,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: _decoration('Confirm password'),
                        validator: (value) => value != _password.text
                            ? 'The passwords do not match.'
                            : _required(value, 'your password again'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use a strong password with uppercase and lowercase letters, a number, and a symbol.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF777A72),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_step == _AccountStep.verify) ...[
                      TextFormField(
                        key: const Key('reset-code'),
                        controller: _code,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: _decoration('Reset code'),
                        validator: (value) => value?.length != 6
                            ? 'Enter the six-digit code.'
                            : null,
                      ),
                      TextButton(
                        onPressed: _busy || _resendSeconds > 0
                            ? null
                            : _resendReset,
                        child: Text(
                          _resendSeconds > 0
                              ? 'Resend code in ${_resendSeconds}s'
                              : 'Resend reset code',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (login || register || _step == _AccountStep.forgot)
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'Connection settings',
                            style: TextStyle(fontSize: 12),
                          ),
                          childrenPadding: const EdgeInsets.only(bottom: 16),
                          children: [
                            TextFormField(
                              key: const Key('account-server'),
                              controller: _baseUrl,
                              enabled: !_busy,
                              keyboardType: TextInputType.url,
                              decoration: _decoration('Jotter API address'),
                              validator: (value) {
                                final uri = Uri.tryParse(value?.trim() ?? '');
                                return uri == null ||
                                        !uri.hasAuthority ||
                                        !['http', 'https'].contains(uri.scheme)
                                    ? 'Enter an http or https API address.'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use the address of your running Jotter server.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    if (_error != null) _message(_error!, error: true),
                    if (_notice != null) _message(_notice!),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_action),
                    ),
                    if (login) ...[
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _go(_AccountStep.forgot),
                        child: const Text('Forgot password?'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _go(_AccountStep.register),
                        child: const Text('Create an account'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                _email.text = 'demo@jotter.app';
                                _password.text = 'Demo@123';
                              },
                        child: const Text('Use demo credentials'),
                      ),
                    ] else
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                _resetTicket = null;
                                _resetBaseUrl = null;
                                _go(_AccountStep.signIn);
                              },
                        child: const Text('Back to sign in'),
                      ),
                    const SizedBox(height: 10),
                    const Text(
                      'The preview workspace is separate from your account. Preview changes last for this session only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _message(String text, {bool error = false}) => Builder(
  builder: (context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: error ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: error
                ? colors.onErrorContainer
                : colors.onSecondaryContainer,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  },
);

class _ActivationDialog extends StatefulWidget {
  const _ActivationDialog({
    required this.repository,
    required this.initialCooldown,
  });
  final ApiNoteRepository repository;
  final int initialCooldown;
  @override
  State<_ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<_ActivationDialog> {
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  String? _notice;
  int _seconds = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _cooldown(widget.initialCooldown);
  }

  void _cooldown(int seconds) {
    _timer?.cancel();
    _seconds = seconds;
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _seconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _seconds = 0);
        return;
      }
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.confirmActivation(_code.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = accountErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _seconds > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final seconds = await widget.repository.resendActivation();
      if (!mounted) return;
      setState(() => _notice = 'A new activation code has been sent.');
      _cooldown(seconds);
    } catch (error) {
      if (mounted) setState(() => _error = accountErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Confirm your email'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the six-digit code sent to ${widget.repository.account.email}. You need to activate your account before using protected account features.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('activation-code'),
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Activation code',
                  ),
                  validator: (value) =>
                      value?.length != 6 ? 'Enter the six-digit code.' : null,
                ),
                const SizedBox(height: 12),
                if (_error != null) _message(_error!, error: true),
                if (_notice != null) _message(_notice!),
                TextButton(
                  onPressed: _busy || _seconds > 0 ? null : _resend,
                  child: Text(
                    _seconds > 0
                        ? 'Resend code in ${_seconds}s'
                        : 'Resend activation code',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: Text(_busy ? 'Confirming…' : 'Confirm email'),
        ),
      ],
    ),
  );
}
