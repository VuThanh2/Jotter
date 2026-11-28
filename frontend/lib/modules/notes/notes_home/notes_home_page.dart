import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/note_ids.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/labels/label_filter/label_filter_bar.dart';
import 'package:jotter/modules/labels/label_picker/label_picker_sheet.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/modules/notes/notes_home/note_card_actions.dart';
import 'package:jotter/modules/notes/notes_home/notes_home_cubit.dart';
import 'package:jotter/modules/notes/notes_home/notes_home_state.dart';
import 'package:jotter/modules/notes/shared/delete_note_dialog.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/profile/preferences/preferences_state.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/note_card.dart';
import 'package:jotter/shared/widgets/note_collection.dart';
import 'package:jotter/shared/widgets/note_search_bar.dart';
import 'package:jotter/shared/widgets/page_shortcuts.dart';
import 'package:jotter/shared/widgets/permission_badge.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class NotesHomePage extends StatelessWidget {
  const NotesHomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        NotesHomeCubit(context.read<NoteStore>(), context.read<LabelStore>()),
    child: const _NotesHomeView(),
  );
}

class _NotesHomeView extends StatefulWidget {
  const _NotesHomeView();

  @override
  State<_NotesHomeView> createState() => _NotesHomeViewState();
}

class _NotesHomeViewState extends State<_NotesHomeView> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _fabExtended = true;

  /// The phone FAB shows its label at rest and tucks it away while the
  /// list scrolls down, so it never covers the cards being read.
  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final extended = switch (notification.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => notification.metrics.pixels < 24 || _fabExtended,
    };
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _newNote() {
    final labels = context.read<NotesHomeCubit>().state.selectedLabelIds;
    context.push(AppRoutes.newNote(newNoteId(), labelIds: labels.toList()));
  }

  void _open(JotterNote note) => context.push(AppRoutes.note(note.id));

  void _notify(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onAction(JotterNote note, NoteCardAction action) async {
    final cubit = context.read<NotesHomeCubit>();
    switch (action) {
      case NoteCardAction.pin:
        _notify(await cubit.togglePin(note));
      case NoteCardAction.labels:
        final labels = await showLabelPicker(context, selected: note.labelIds);
        if (labels != null) _notify(await cubit.setLabels(note, labels));
      case NoteCardAction.delete:
        if (note.isProtected) {
          // A locked note must be unlocked in the editor before deleting it.
          _notify('Unlock this note first, then delete it from the editor.');
          _open(note);
          return;
        }
        if (!await confirmDeleteNote(context, note)) return;
        final error = await cubit.delete(note);
        _notify(error ?? 'Note deleted.');
    }
  }

  @override
  Widget build(BuildContext context) => PageShortcuts(
    autofocus: true,
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newNote,
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newNote,
      // Browsers keep Ctrl+N for a new window.
      const SingleActivator(LogicalKeyboardKey.keyN, alt: true): _newNote,
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          _searchFocus.requestFocus,
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          _searchFocus.requestFocus,
    },
    child: Scaffold(
      floatingActionButton: context.isCompact
          ? FloatingActionButton.extended(
              key: const Key('new-note-fab'),
              tooltip: 'New note',
              onPressed: _newNote,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded),
                  AnimatedSize(
                    duration: JotterMotion.medium,
                    curve: JotterMotion.curve,
                    child: _fabExtended
                        ? const Padding(
                            padding: EdgeInsets.only(left: 8, right: 4),
                            child: Text('New note'),
                          )
                        : const SizedBox(height: 24),
                  ),
                ],
              ),
            )
          : null,
      body: BlocBuilder<NotesHomeCubit, NotesHomeState>(
        builder: (context, state) {
          final preferences = context.watch<PreferencesCubit>().state;
          final horizontal = context.isCompact ? 16.0 : 32.0;
          return RefreshIndicator(
            onRefresh: context.read<NotesHomeCubit>().refresh,
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onScroll,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 8),
                    sliver: SliverToBoxAdapter(
                      child: _Header(
                        state: state,
                        search: _search,
                        searchFocus: _searchFocus,
                        listMode: preferences.listMode,
                        onNewNote: _newNote,
                      ),
                    ),
                  ),
                  if (state.refreshing && state.status != NotesStatus.loading)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        0,
                        horizontal,
                        8,
                      ),
                      sliver: const SliverToBoxAdapter(
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            semanticsLabel: 'Refreshing notes',
                          ),
                        ),
                      ),
                    ),
                  ..._body(context, state, preferences, horizontal),
                  const SliverToBoxAdapter(child: SizedBox(height: 104)),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  List<Widget> _body(
    BuildContext context,
    NotesHomeState state,
    PreferencesState preferences,
    double horizontal,
  ) {
    Widget fill(Widget child) =>
        SliverFillRemaining(hasScrollBody: false, child: child);
    if (state.status == NotesStatus.loading ||
        (state.searching && state.searchResults == null)) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 0),
          sliver: NoteSkeletonSliver(listMode: preferences.listMode),
        ),
      ];
    }
    if (state.status == NotesStatus.failure) {
      return [
        fill(
          ErrorView(
            message: state.error ?? 'Your notes could not be loaded.',
            onRetry: context.read<NotesHomeCubit>().refresh,
          ),
        ),
      ];
    }
    if (state.isSearching && state.error != null) {
      return [
        fill(
          ErrorView(
            message: state.error!,
            onRetry: context.read<NotesHomeCubit>().retrySearch,
          ),
        ),
      ];
    }
    final pinned = state.pinned;
    final others = state.others;
    if (pinned.isEmpty && others.isEmpty) return [fill(_emptyState(state))];
    Widget card(BuildContext context, JotterNote note) => NoteCard(
      key: ValueKey(note.id),
      note: note,
      labels: state.labels,
      listMode: preferences.listMode,
      color: preferences.noteColor,
      onOpen: () => _open(note),
      onLongPress: note.isOwned && context.isCompact
          ? () => showNoteActionSheet(
              context,
              note,
              (action) => _onAction(note, action),
            )
          : null,
      menu: note.isOwned
          ? NoteCardMenu(
              note: note,
              onSelected: (action) => _onAction(note, action),
            )
          : null,
      footer: note.isOwned ? null : PermissionBadge(canEdit: note.canEdit),
    );
    Widget section(String title, IconData icon, List<JotterNote> notes) =>
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: NoteSectionHeading(
                  title,
                  icon: icon,
                  count: notes.length,
                ),
              ),
              NoteCollectionSliver(
                notes: notes,
                listMode: preferences.listMode,
                itemBuilder: card,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        );
    return [
      if (pinned.isNotEmpty) section('Pinned', Icons.push_pin_outlined, pinned),
      if (others.isNotEmpty)
        section(
          state.isSearching
              ? 'Results'
              : pinned.isEmpty
              ? 'Notes'
              : 'Others',
          Icons.notes_rounded,
          others,
        ),
    ];
  }

  Widget _emptyState(NotesHomeState state) {
    final cubit = context.read<NotesHomeCubit>();
    if (state.isSearching) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: 'Nothing matches “${state.query.trim()}”',
        message: 'Try another word. Search looks at titles and content.',
        action: OutlinedButton(
          onPressed: () {
            _search.clear();
            cubit.search('');
          },
          child: const Text('Clear search'),
        ),
      );
    }
    if (state.isFiltering) {
      return EmptyView(
        icon: Icons.label_off_outlined,
        title: 'No notes with these labels',
        message: 'Choose other labels or clear the filter.',
        action: OutlinedButton(
          onPressed: cubit.clearLabels,
          child: const Text('Clear filter'),
        ),
      );
    }
    return EmptyView(
      icon: Icons.edit_note_rounded,
      title: 'Good things start with a note',
      message: 'Capture an idea, make a list, or just start writing.',
      action: FilledButton.icon(
        onPressed: _newNote,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Write your first note'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.search,
    required this.searchFocus,
    required this.listMode,
    required this.onNewNote,
  });

  final NotesHomeState state;
  final TextEditingController search;
  final FocusNode searchFocus;
  final bool listMode;
  final VoidCallback onNewNote;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotesHomeCubit>();
    final preferences = context.read<PreferencesCubit>();
    final palette = context.jotterColors;
    final compact = context.isCompact;
    final count = state.notes.where((note) => note.isOwned).length;
    final pinned = state.notes.where((n) => n.isOwned && n.isPinned).length;
    final summary = [
      '$count ${count == 1 ? 'note' : 'notes'}',
      if (pinned > 0) '$pinned pinned',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: compact
                        ? Theme.of(context).textTheme.headlineSmall
                        : Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (state.status == NotesStatus.ready) ...[
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: JotterMotion.fast,
                      child: Text(
                        summary,
                        key: ValueKey(summary),
                        style: TextStyle(fontSize: 13.5, color: palette.muted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SegmentedButton<bool>(
              key: const Key('view-toggle'),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.grid_view_rounded, size: 18),
                  tooltip: 'Grid view',
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.view_agenda_outlined, size: 18),
                  tooltip: 'List view',
                ),
              ],
              selected: {listMode},
              onSelectionChanged: (value) => preferences.update(
                preferences.state.preferences.copyWith(
                  listViewMode: value.single ? 'List' : 'Grid',
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              Tooltip(
                message: 'New note (Alt+N)',
                child: FilledButton.icon(
                  key: const Key('new-note'),
                  onPressed: onNewNote,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New note'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        NoteSearchBar(
          controller: search,
          focusNode: searchFocus,
          onChanged: cubit.search,
          shortcutHint: !compact,
        ),
        SizedBox(
          height: 3,
          child: state.searching && state.searchResults != null
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        const SizedBox(height: 10),
        LabelFilterBar(
          labels: state.labels,
          selected: state.selectedLabelIds,
          onToggle: cubit.toggleLabel,
          onClear: cubit.clearLabels,
        ),
        if (state.error != null &&
            state.status == NotesStatus.ready &&
            !state.isSearching) ...[
          const SizedBox(height: 12),
          MessageStrip(state.error!, error: true),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}
