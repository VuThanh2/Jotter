import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/modules/labels/label_picker/label_picker_cubit.dart';
import 'package:jotter/modules/labels/label_picker/label_picker_state.dart';
import 'package:jotter/modules/labels/shared/label_name_dialog.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/modal_panel.dart';
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
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: picker,
    );
  }
  return showJotterDialog<List<String>>(
    context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: picker(context),
        ),
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
  Widget build(
    BuildContext context,
  ) => BlocBuilder<LabelPickerCubit, LabelPickerState>(
    builder: (context, state) {
      final cubit = context.read<LabelPickerCubit>();
      final palette = context.jotterColors;
      final count = state.selected.length;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Labels',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: JotterMotion.fast,
                      child: Text(
                        count == 0 ? 'None selected' : '$count selected',
                        key: ValueKey(count),
                        style: TextStyle(fontSize: 13, color: palette.muted),
                      ),
                    ),
                  ],
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
                    if (state.labels.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          'No labels yet. Create one to group related '
                          'notes.',
                          style: TextStyle(color: palette.muted),
                        ),
                      ),
                    for (final label in state.labels)
                      CheckboxListTile(
                        value: state.selected.contains(label.id),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        secondary: Icon(
                          Icons.label_outline_rounded,
                          color: state.selected.contains(label.id)
                              ? palette.accent
                              : palette.muted,
                        ),
                        title: Text(label.name),
                        onChanged: (_) => cubit.toggle(label.id),
                      ),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(Icons.add_rounded, color: palette.accent),
                      title: Text(
                        'New label',
                        style: TextStyle(
                          color: palette.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _create(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
