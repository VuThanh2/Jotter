import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';
import 'package:jotter/modules/profile/shared/me_state.dart';

/// Shown on every signed-in screen until the email address is confirmed.
class UnverifiedBanner extends StatelessWidget {
  const UnverifiedBanner({super.key, this.compact = false});

  /// A small chip for full-screen pages such as the note editor.
  final bool compact;

  @override
  Widget build(BuildContext context) => BlocBuilder<MeCubit, MeState>(
    buildWhen: (a, b) => a.account.isActivated != b.account.isActivated,
    builder: (context, state) {
      if (state.account.isActivated) return const SizedBox.shrink();
      void open() => context.push(AppRoutes.activation);
      if (compact) {
        return Tooltip(
          message: 'Confirm your email address',
          child: ActionChip(
            avatar: const Icon(Icons.mark_email_unread_outlined, size: 16),
            label: const Text('Unverified'),
            onPressed: open,
          ),
        );
      }
      return Material(
        color: context.jotterColors.tint(JotterColors.butter),
        child: Semantics(
          container: true,
          label: 'Your email address is not confirmed yet',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 18,
                  color: JotterColors.accent,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your email is not confirmed yet.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  key: const Key('verify-email'),
                  onPressed: open,
                  child: const Text('Confirm now'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
