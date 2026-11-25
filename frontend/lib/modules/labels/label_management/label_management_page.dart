import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/modules/labels/label_management/label_management_cubit.dart';
import 'package:jotter/modules/labels/label_management/label_management_state.dart';
import 'package:jotter/modules/labels/shared/label_name_dialog.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/shared/widgets/confirm_dialog.dart';
import 'package:jotter/shared/widgets/page_frame.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class LabelManagementPage extends StatelessWidget {
  const LabelManagementPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => LabelManagementCubit(context.read<LabelStore>()),
    child: const _LabelManagementView(),
  );
}

class _LabelManagementView extends StatelessWidget {
  const _LabelManagementView();

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<LabelManagementCubit>();
    final name = await showLabelNameDialog(
      context,
      title: 'New label',
      action: 'Create',
    );
    if (name != null) await cubit.create(name);
  }

  Future<void> _rename(BuildContext context, JotterLabel label) async {
    final cubit = context.read<LabelManagementCubit>();
    final name = await showLabelNameDialog(
      context,
      title: 'Rename label',
      action: 'Rename',
      initialName: label.name,
    );
    if (name != null && name != label.name) await cubit.rename(label.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    JotterLabel label,
    int count,
  ) async {
    final cubit = context.read<LabelManagementCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete “${label.name}”?',
      message: count == 0
          ? 'No notes use this label.'
          : 'The label is removed from $count note${count == 1 ? '' : 's'}. '
                'The notes themselves are kept.',
      confirmLabel: 'Delete label',
    );
    if (confirmed) await cubit.delete(label.id);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    banner: const UnverifiedBanner(),
    title: 'Labels',
    fallbackRoute: AppRoutes.notes,
    actions: [
      IconButton(
        key: const Key('add-label'),
        tooltip: 'New label',
        onPressed: () => _create(context),
        icon: const Icon(Icons.add_rounded),
      ),
    ],
    child: BlocBuilder<LabelManagementCubit, LabelManagementState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.busy) const LinearProgressIndicator(minHeight: 2),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            MessageStrip(state.error!, error: true),
          ],
          if (state.labels.isEmpty)
            EmptyView(
              icon: Icons.label_outline_rounded,
              title: 'No labels yet',
              message: 'Labels keep related notes together.',
              action: FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create a label'),
              ),
            )
          else
            for (final label in state.labels)
              _LabelRow(
                label: label,
                count: state.noteCounts[label.id] ?? 0,
                onRename: () => _rename(context, label),
                onDelete: () =>
                    _delete(context, label, state.noteCounts[label.id] ?? 0),
              ),
        ],
      ),
    ),
  );
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({
    required this.label,
    required this.count,
    required this.onRename,
    required this.onDelete,
  });

  final JotterLabel label;
  final int count;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.only(left: 4),
    leading: const Icon(Icons.label_outline_rounded),
    title: Text(label.name),
    subtitle: Text('$count note${count == 1 ? '' : 's'}'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Rename ${label.name}',
          onPressed: onRename,
          icon: const Icon(Icons.edit_outlined, size: 20),
        ),
        IconButton(
          tooltip: 'Delete ${label.name}',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
        ),
      ],
    ),
  );
}
