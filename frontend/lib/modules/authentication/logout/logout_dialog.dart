import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_cubit.dart';
import 'package:jotter/shared/lib/session.dart';
import 'package:jotter/shared/widgets/confirm_dialog.dart';

Future<void> confirmLogout(BuildContext context) async {
  final pending = context.read<SyncStatusCubit>().state.pendingCount;
  final session = context.read<SessionCubit>();
  final confirmed = await showConfirmDialog(
    context,
    title: 'Sign out?',
    icon: Icons.logout_rounded,
    message: pending == 0
        ? 'Your notes stay safe in your account. This device forgets them '
              'until you sign in again.'
        : '$pending change${pending == 1 ? ' has' : 's have'} not synced yet '
              'and will be lost if you sign out now.',
    confirmLabel: pending == 0 ? 'Sign out' : 'Sign out anyway',
    destructive: pending > 0,
  );
  if (confirmed) await session.signOut();
}
