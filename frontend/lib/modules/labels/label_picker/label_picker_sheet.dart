import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/modules/labels/label_picker/label_picker_cubit.dart';
import 'package:jotter/modules/labels/label_picker/label_picker_state.dart';
import 'package:jotter/modules/labels/shared/label_name_dialog.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/state_views.dart';

/// Returns the chosen label ids, or null when dismissed.
Future<List<String>?> showLabelPicker(
  BuildContext context, {
  required List<String> selected,
}) {
  final store = context.read<LabelStore>();
  Widget picker(BuildContext _) => BlocProvider(
    create: (_) => LabelPickerCubit(store, selected),
    child: const _LabelPicker(),
  );
  if (context.isCompact) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: picker,
    );
  }
  return showDialog<List<String>>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
        child: picker(context),
      ),
    ),
  );
}

class _LabelPicker extends StatelessWidget {
  const _LabelPicker();

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<LabelPickerCubit>();
    final name = await showLabelNameDialog(
      context,
      title: 'New label',
      action: 'Create',
    );
    if (name != null) await cubit.create(name);
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LabelPickerCubit, LabelPickerState>(
        builder: (context, state) {
          final cubit = context.read<LabelPickerCubit>();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Labels',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: MessageStrip(state.error!, error: true),
                    ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final label in state.labels)
                          CheckboxListTile(
                            value: state.selected.contains(label.id),
                            title: Text(label.name),
                            onChanged: (_) => cubit.toggle(label.id),
                          ),
                        ListTile(
                          leading: const Icon(Icons.add_rounded),
                          title: const Text('New label'),
                          onTap: () => _create(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: FilledButton(
                      key: const Key('apply-labels'),
                      onPressed: () =>
                          Navigator.pop(context, state.selected.toList()),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
