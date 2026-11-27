import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/modules/protection/manage_protection/manage_protection_cubit.dart';
import 'package:jotter/modules/protection/manage_protection/manage_protection_state.dart';
import 'package:jotter/shared/widgets/modal_panel.dart';
import 'package:jotter/shared/widgets/password_field.dart';
import 'package:jotter/shared/widgets/state_views.dart';

enum NotePasswordInput { current, newPassword, confirmation }

/// A password form that stays open until [onSubmit] succeeds, so a wrong
/// password can be corrected in place. Resolves to true on success.
Future<bool> showNotePasswordDialog(
  BuildContext context,
  ManageProtectionCubit cubit, {
  required String title,
  required List<NotePasswordInput> inputs,
  required String submitLabel,
  required Future<bool> Function(Map<NotePasswordInput, String> values)
  onSubmit,
  String? message,
  bool destructive = false,
}) async {
  cubit.clearError();
  final done = await showJotterDialog<bool>(
    context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _NotePasswordDialog(
        title: title,
        message: message,
        inputs: inputs,
        submitLabel: submitLabel,
        destructive: destructive,
        onSubmit: onSubmit,
      ),
    ),
  );
  if (done != true && !cubit.isClosed) cubit.clearError();
  return done ?? false;
}

class _NotePasswordDialog extends StatefulWidget {
  const _NotePasswordDialog({
    required this.title,
    required this.message,
    required this.inputs,
    required this.submitLabel,
    required this.destructive,
    required this.onSubmit,
  });

  final String title;
  final String? message;
  final List<NotePasswordInput> inputs;
  final String submitLabel;
  final bool destructive;
  final Future<bool> Function(Map<NotePasswordInput, String>) onSubmit;

  @override
  State<_NotePasswordDialog> createState() => _NotePasswordDialogState();
}

class _NotePasswordDialogState extends State<_NotePasswordDialog> {
  final _form = GlobalKey<FormState>();
  late final _controllers = {
    for (final input in widget.inputs) input: TextEditingController(),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (context.read<ManageProtectionCubit>().state.busy ||
        !_form.currentState!.validate()) {
      return;
    }
    final ok = await widget.onSubmit({
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    });
    if (ok && mounted) Navigator.pop(context, true);
  }

  String _label(NotePasswordInput input) => switch (input) {
    NotePasswordInput.current => 'Current note password',
    NotePasswordInput.newPassword =>
      widget.inputs.contains(NotePasswordInput.current)
          ? 'New note password'
          : 'Note password',
    NotePasswordInput.confirmation => 'Confirm password',
  };

  String? _validate(NotePasswordInput input, String? value) {
    final text = value ?? '';
    return switch (input) {
      NotePasswordInput.current =>
        text.isEmpty ? 'Enter the current note password.' : null,
      NotePasswordInput.newPassword =>
        text.length < 4 || text.length > 128
            ? 'Use 4 to 128 characters.'
            : null,
      NotePasswordInput.confirmation =>
        text != _controllers[NotePasswordInput.newPassword]!.text
            ? 'The passwords do not match.'
            : null,
    };
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ManageProtectionCubit, ManageProtectionState>(
        builder: (context, state) {
          final scheme = Theme.of(context).colorScheme;
          final last = widget.inputs.last;
          return AlertDialog(
            icon: Icon(
              widget.destructive
                  ? Icons.lock_open_rounded
                  : Icons.password_rounded,
              color: widget.destructive
                  ? scheme.error
                  : context.jotterColors.accent,
            ),
            title: Text(widget.title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.message != null) ...[
                        Text(widget.message!),
                        const SizedBox(height: 18),
                      ],
                      for (final input in widget.inputs) ...[
                        PasswordField(
                          key: ValueKey('note-password-${input.name}'),
                          controller: _controllers[input]!,
                          label: _label(input),
                          autofocus: input == widget.inputs.first,
                          enabled: !state.busy,
                          newPassword: input != NotePasswordInput.current,
                          validator: (value) => _validate(input, value),
                          textInputAction: input == last
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onSubmitted: input == last ? (_) => _submit() : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (state.error != null)
                        MessageStrip(state.error!, error: true),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: state.busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('note-password-submit'),
                style: widget.destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      )
                    : null,
                onPressed: state.busy ? null : _submit,
                child: Text(widget.submitLabel),
              ),
            ],
          );
        },
      );
}
