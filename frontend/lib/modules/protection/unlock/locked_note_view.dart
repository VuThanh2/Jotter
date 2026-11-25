import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/shared/widgets/password_field.dart';
import 'package:jotter/shared/widgets/state_views.dart';

/// Shown in place of the editor while a protected note is locked.
class LockedNoteView extends StatefulWidget {
  const LockedNoteView({
    super.key,
    required this.title,
    required this.busy,
    required this.onUnlock,
    this.error,
  });

  final String title;
  final bool busy;
  final String? error;
  final ValueChanged<String> onUnlock;

  @override
  State<LockedNoteView> createState() => _LockedNoteViewState();
}

class _LockedNoteViewState extends State<LockedNoteView> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) widget.onUnlock(_password.text);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: context.jotterColors.muted,
              ),
              const SizedBox(height: 16),
              Text(
                widget.title.isEmpty ? 'Locked note' : widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the note password to open it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.jotterColors.muted),
              ),
              const SizedBox(height: 24),
              PasswordField(
                key: const Key('unlock-password'),
                controller: _password,
                label: 'Note password',
                autofocus: true,
                enabled: !widget.busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              if (widget.error != null) ...[
                MessageStrip(widget.error!, error: true),
                const SizedBox(height: 16),
              ],
              FilledButton(
                key: const Key('unlock-submit'),
                onPressed: widget.busy ? null : _submit,
                child: Text(widget.busy ? 'Unlocking…' : 'Unlock'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
