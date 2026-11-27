import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/sync_status.dart';
import 'package:jotter/modules/authentication/logout/logout_dialog.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';
import 'package:jotter/modules/profile/shared/me_state.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_cubit.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_sheet.dart';
import 'package:jotter/shared/widgets/page_frame.dart';
import 'package:jotter/shared/widgets/settings_group.dart';
import 'package:jotter/shared/widgets/user_avatar.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
    banner: const UnverifiedBanner(),
    title: 'Account',
    subtitle: 'Your profile, sign-in and workspace settings.',
    icon: Icons.manage_accounts_outlined,
    fallbackRoute: AppRoutes.notes,
    aside: BlocBuilder<MeCubit, MeState>(
      builder: (context, me) => _ProfileCard(me: me, vertical: true),
    ),
    child: BlocBuilder<MeCubit, MeState>(
      builder: (context, me) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!context.isExpanded) ...[
            const SizedBox(height: 12),
            _ProfileCard(me: me),
            const SizedBox(height: 28),
          ],
          SettingsGroup(
            title: 'Account',
            children: [
              if (!me.account.isActivated)
                const _RouteTile(
                  icon: Icons.mark_email_unread_outlined,
                  tint: JotterColors.butter,
                  title: 'Confirm your email',
                  subtitle: 'Enter the code we sent you',
                  route: AppRoutes.activation,
                  highlight: true,
                ),
              const _RouteTile(
                icon: Icons.person_outline_rounded,
                tint: JotterColors.peach,
                title: 'Edit profile',
                subtitle: 'Name and photo',
                route: AppRoutes.profile,
              ),
              const _RouteTile(
                icon: Icons.lock_outline_rounded,
                tint: JotterColors.lavender,
                title: 'Change password',
                subtitle: 'Used to sign in on every device',
                route: AppRoutes.password,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            title: 'Workspace',
            children: [
              const _RouteTile(
                icon: Icons.tune_rounded,
                tint: JotterColors.sage,
                title: 'Preferences',
                subtitle: 'Theme, text size, note color and layout',
                route: AppRoutes.preferences,
              ),
              const _RouteTile(
                icon: Icons.label_outline_rounded,
                tint: JotterColors.sky,
                title: 'Labels',
                subtitle: 'Create, rename and remove labels',
                route: AppRoutes.labels,
              ),
              BlocBuilder<SyncStatusCubit, WorkspaceSyncStatus>(
                builder: (context, status) => SettingsTile(
                  icon: Icons.cloud_sync_outlined,
                  tint: JotterColors.butter,
                  title: 'Sync status',
                  subtitle: status.label,
                  onTap: () => showSyncStatusSheet(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            children: [
              SettingsTile(
                key: const Key('sign-out'),
                icon: Icons.logout_rounded,
                title: 'Sign out',
                destructive: true,
                showChevron: false,
                onTap: () => confirmLogout(context),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.me, this.vertical = false});

  final MeState me;

  /// The desktop column: avatar above the details, with a shortcut to edit.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final verified = me.account.isActivated;
    final status = palette.tone(
      verified ? JotterTone.success : JotterTone.warning,
    );
    final avatar = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surface,
        shape: BoxShape.circle,
        boxShadow: palette.softShadow,
      ),
      child: UserAvatar(
        name: me.account.displayName,
        image: me.avatar,
        radius: vertical ? 42 : 30,
      ),
    );
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_outlined : Icons.schedule_rounded,
            size: 13,
            color: status.icon,
          ),
          const SizedBox(width: 5),
          Text(
            verified ? 'Email confirmed' : 'Email not confirmed',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: status.foreground,
            ),
          ),
        ],
      ),
    );
    if (vertical) {
      return Container(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.line),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.tint(JotterColors.peach), palette.surface],
            stops: const [0, .45],
          ),
        ),
        child: Column(
          children: [
            avatar,
            const SizedBox(height: 16),
            Text(
              me.account.displayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              me.account.email,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted),
            ),
            const SizedBox(height: 12),
            chip,
            const SizedBox(height: 20),
            Divider(color: palette.line),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.profile),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit profile'),
              ),
            ),
            if (!verified) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.activation),
                  icon: const Icon(Icons.mark_email_read_outlined, size: 17),
                  label: const Text('Confirm email'),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.surface, palette.tint(JotterColors.peach)],
        ),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me.account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  me.account.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted),
                ),
                const SizedBox(height: 10),
                chip,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.route,
    this.subtitle,
    this.highlight = false,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final String route;
  final bool highlight;

  @override
  Widget build(BuildContext context) => SettingsTile(
    icon: icon,
    tint: tint,
    title: title,
    subtitle: subtitle,
    highlight: highlight,
    onTap: () => context.push(route),
  );
}
