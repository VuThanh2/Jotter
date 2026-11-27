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
import 'package:jotter/shared/widgets/user_avatar.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
    banner: const UnverifiedBanner(),
    title: 'Account',
    fallbackRoute: AppRoutes.notes,
    child: BlocBuilder<MeCubit, MeState>(
      builder: (context, me) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              UserAvatar(
                name: me.account.displayName,
                image: me.avatar,
                radius: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me.account.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      me.account.email,
                      style: TextStyle(color: context.jotterColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!me.account.isActivated)
            _Tile(
              icon: Icons.mark_email_unread_outlined,
              title: 'Confirm your email',
              subtitle: 'Enter the code we sent you',
              route: AppRoutes.activation,
              highlight: true,
            ),
          const _Tile(
            icon: Icons.person_outline_rounded,
            title: 'Edit profile',
            subtitle: 'Name and photo',
            route: AppRoutes.profile,
          ),
          const _Tile(
            icon: Icons.tune_rounded,
            title: 'Preferences',
            subtitle: 'Theme, text size, note color and layout',
            route: AppRoutes.preferences,
          ),
          const _Tile(
            icon: Icons.lock_outline_rounded,
            title: 'Change password',
            route: AppRoutes.password,
          ),
          const _Tile(
            icon: Icons.label_outline_rounded,
            title: 'Labels',
            route: AppRoutes.labels,
          ),
          BlocBuilder<SyncStatusCubit, WorkspaceSyncStatus>(
            builder: (context, status) => ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Sync status'),
              subtitle: Text(status.label),
              onTap: () => showSyncStatusSheet(context),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            key: const Key('sign-out'),
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () => confirmLogout(context),
          ),
        ],
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.route,
    this.subtitle,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String route;
  final bool highlight;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: highlight ? JotterColors.accent : null),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.push(route),
  );
}
