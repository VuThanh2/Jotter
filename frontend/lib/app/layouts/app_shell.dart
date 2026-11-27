import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/modules/profile/shared/account_entry.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_cubit.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_state.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_indicator.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/jotter_mark.dart';

/// Frame of every signed-in tab: bottom bar on phones, rail on wider screens.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _sharedBranch = 1;
  static const _destinations = [
    (Icons.notes_outlined, Icons.notes_rounded, 'Notes'),
    (Icons.people_outline_rounded, Icons.people_rounded, 'Shared'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Ask AI'),
  ];

  void _select(BuildContext context, int index) {
    if (index == _sharedBranch) context.read<ShareInboxCubit>().markViewed();
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  /// The Shared icon carries a count of notes not yet seen there.
  static Widget _icon(IconData icon, int index, int unviewed) =>
      index == _sharedBranch
      ? Badge.count(
          count: unviewed,
          isLabelVisible: unviewed > 0,
          child: Icon(icon),
        )
      : Icon(icon);

  @override
  Widget build(BuildContext context) =>
      BlocListener<ShareInboxCubit, ShareInboxState>(
        listenWhen: (previous, current) =>
            current.unviewed > previous.unviewed &&
            shell.currentIndex == _sharedBranch,
        listener: (context, _) => context.read<ShareInboxCubit>().markViewed(),
        child: BlocSelector<ShareInboxCubit, ShareInboxState, int>(
          selector: (state) => state.unviewed,
          builder: _frame,
        ),
      );

  Widget _frame(BuildContext context, int unviewed) {
    final size = context.windowSize;
    final content = Column(
      children: [
        const UnverifiedBanner(),
        Expanded(child: shell),
      ],
    );
    if (size == WindowSize.compact) {
      return Scaffold(
        appBar: AppBar(
          title: const JotterMark(size: 20),
          actions: const [
            SyncStatusIndicator(),
            AccountEntry(),
            SizedBox(width: 4),
          ],
        ),
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => _select(context, index),
          destinations: [
            for (final (index, (icon, selected, label))
                in _destinations.indexed)
              NavigationDestination(
                icon: _icon(icon, index, unviewed),
                selectedIcon: _icon(selected, index, unviewed),
                label: label,
              ),
          ],
        ),
      );
    }
    final extended = size == WindowSize.expanded;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: 208,
              backgroundColor: context.jotterColors.sidebar,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) => _select(context, index),
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 20),
                child: JotterMark(size: 22, showWord: extended),
              ),
              trailing: const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SyncStatusIndicator(),
                        AccountEntry(radius: 18),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final (index, (icon, selected, label))
                    in _destinations.indexed)
                  NavigationRailDestination(
                    icon: _icon(icon, index, unviewed),
                    selectedIcon: _icon(selected, index, unviewed),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
