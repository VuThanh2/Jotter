import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/modules/profile/shared/account_entry.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';
import 'package:jotter/modules/profile/shared/me_state.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_cubit.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_state.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_indicator.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/jotter_mark.dart';
import 'package:jotter/shared/widgets/user_avatar.dart';

/// Frame of every signed-in tab: a bottom bar on phones, a rail on tablets
/// and a full sidebar on desktop browsers.
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
    final palette = context.jotterColors;
    final content = Column(
      children: [
        const UnverifiedBanner(),
        Expanded(
          child: _BranchFade(index: shell.currentIndex, child: shell),
        ),
      ],
    );
    if (size == WindowSize.compact) {
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: const JotterMark(size: 20),
          actions: const [
            SyncStatusIndicator(),
            AccountEntry(),
            SizedBox(width: 6),
          ],
        ),
        body: content,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.line)),
          ),
          child: NavigationBar(
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
        ),
      );
    }
    final Widget navigation = size == WindowSize.expanded
        ? _Sidebar(
            selectedIndex: shell.currentIndex,
            unviewed: unviewed,
            onSelect: (index) => _select(context, index),
          )
        : NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) => _select(context, index),
            labelType: NavigationRailLabelType.all,
            groupAlignment: -.85,
            leading: const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 12),
              child: JotterMark(size: 22, showWord: false),
            ),
            trailing: const Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SyncStatusIndicator(compact: true),
                      SizedBox(height: 4),
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
          );
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            navigation,
            VerticalDivider(width: 1, color: palette.line),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

/// Fades the tab in when it changes, keeping every tab's state alive.
class _BranchFade extends StatefulWidget {
  const _BranchFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchFade> createState() => _BranchFadeState();
}

class _BranchFadeState extends State<_BranchFade>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: JotterMotion.medium,
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: JotterMotion.curve,
  );

  @override
  void didUpdateWidget(covariant _BranchFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, .012),
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
}

/// Desktop navigation: brand, destinations and the signed-in account.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.unviewed,
    required this.onSelect,
  });

  final int selectedIndex;
  final int unviewed;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Container(
      width: 248,
      color: palette.sidebar,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 28),
            child: Align(
              alignment: Alignment.centerLeft,
              child: JotterMark(size: 22),
            ),
          ),
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              children: [
                for (final (index, (icon, selected, label))
                    in AppShell._destinations.indexed)
                  _SidebarItem(
                    icon: index == selectedIndex ? selected : icon,
                    label: label,
                    selected: index == selectedIndex,
                    badge: index == AppShell._sharedBranch ? unviewed : 0,
                    onTap: () => onSelect(index),
                  ),
              ],
            ),
          ),
          const Spacer(),
          const Align(
            alignment: Alignment.centerLeft,
            child: SyncStatusIndicator(),
          ),
          const SizedBox(height: 6),
          const _SidebarAccount(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final selected = widget.selected;
    final background = selected
        ? palette.surface
        : _hovered
        ? palette.ink.withValues(alpha: .05)
        : Colors.transparent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: JotterMotion.fast,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected ? palette.line : Colors.transparent,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: palette.dark ? .2 : .04,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon,
                        size: 20,
                        color: selected ? palette.accent : palette.muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected ? palette.ink : palette.muted,
                          ),
                        ),
                      ),
                      if (widget.badge > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.badge}',
                            semanticsLabel: '${widget.badge} new',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The signed-in person at the foot of the sidebar; opens the account page.
class _SidebarAccount extends StatelessWidget {
  const _SidebarAccount();

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return BlocBuilder<MeCubit, MeState>(
      builder: (context, me) => Tooltip(
        message: 'Account settings',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('account-entry'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(AppRoutes.account),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  UserAvatar(
                    name: me.account.displayName,
                    image: me.avatar,
                    radius: 17,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.account.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          me.account.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.settings_outlined, size: 18, color: palette.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
