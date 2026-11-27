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
      final verified = state.account.isActivated;
      void open() => context.push(AppRoutes.activation);
      final colors = context.jotterColors.tone(JotterTone.warning);
      if (compact) {
        if (verified) return const SizedBox.shrink();
        return Tooltip(
          message: 'Confirm your email address',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              avatar: Icon(
                Icons.mark_email_unread_outlined,
                size: 16,
                color: colors.icon,
              ),
              label: Text(
                'Unverified',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              backgroundColor: colors.background,
              side: BorderSide(color: colors.border),
              visualDensity: VisualDensity.compact,
              onPressed: open,
            ),
          ),
        );
      }
      // Slides away once the address is confirmed instead of vanishing.
      return AnimatedSize(
        duration: JotterMotion.medium,
        curve: JotterMotion.curve,
        alignment: Alignment.topCenter,
        child: verified
            ? const SizedBox(width: double.infinity)
            : Material(
                color: colors.background,
                child: Semantics(
                  container: true,
                  label: 'Your email address is not confirmed yet',
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.border)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mark_email_unread_outlined,
                          size: 18,
                          color: colors.icon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your email is not confirmed yet.',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: colors.foreground,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const Key('verify-email'),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.foreground,
                          ),
                          onPressed: open,
                          child: const Text('Confirm now'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      );
    },
  );
}
