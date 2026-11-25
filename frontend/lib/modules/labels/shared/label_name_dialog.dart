import 'package:flutter/material.dart';

Future<String?> showLabelNameDialog(
  BuildContext context, {
  required String title,
  required String action,
  String initialName = '',
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _LabelNameDialog(title: title, action: action, initialName: initialName),
);

class _LabelNameDialog extends StatefulWidget {
  const _LabelNameDialog({
    required this.title,
    required this.action,
    required this.initialName,
  });

  final String title;
  final String action;
  final String initialName;

  @override
  State<_LabelNameDialog> createState() => _LabelNameDialogState();
}

class _LabelNameDialogState extends State<_LabelNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 340,
      child: Form(
        key: _form,
        child: TextFormField(
          key: const Key('label-name'),
          controller: _name,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(labelText: 'Label name'),
          onFieldSubmitted: (_) => _submit(),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter a label name.'
              : null,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.action)),
    ],
  );
}
