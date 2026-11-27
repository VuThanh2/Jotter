import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/models/sync_status.dart';
import 'package:jotter/modules/ai/summary/summary_panel.dart';
import 'package:jotter/modules/labels/label_picker/label_picker_sheet.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/modules/notes/attachments/attachment_section.dart';
import 'package:jotter/modules/notes/attachments/attachments_api.dart';
import 'package:jotter/modules/notes/attachments/attachments_cubit.dart';
import 'package:jotter/modules/notes/note_editor/editor_action_bar.dart';
import 'package:jotter/modules/notes/note_editor/note_editor_bloc.dart';
import 'package:jotter/modules/notes/note_editor/note_editor_event.dart';
import 'package:jotter/modules/notes/note_editor/note_editor_state.dart';
import 'package:jotter/modules/notes/note_editor/save_status_indicator.dart';
import 'package:jotter/modules/notes/note_editor/unavailable_note_view.dart';
import 'package:jotter/modules/notes/shared/delete_note_dialog.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/modules/protection/manage_protection/protection_panel.dart';
import 'package:jotter/modules/protection/unlock/locked_note_view.dart';
import 'package:jotter/modules/sharing/share_note/share_dialog.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_cubit.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_sheet.dart';
import 'package:jotter/shared/lib/file_service.dart';
import 'package:jotter/shared/widgets/note_card.dart';
import 'package:jotter/shared/widgets/page_frame.dart';
import 'package:jotter/shared/widgets/page_shortcuts.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/state_views.dart';
import 'package:jotter/shared/widgets/user_avatar.dart';

/// One editor for creating and editing. Saving happens automatically.
class NoteEditorPage extends StatelessWidget {
  const NoteEditorPage({
    super.key,
    required this.noteId,
    this.isNew = false,
    this.initialLabelIds = const [],
  });

  final String noteId;
  final bool isNew;
  final List<String> initialLabelIds;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) => NoteEditorBloc(
          context.read<NoteStore>(),
          noteId: noteId,
          isNew: isNew,
          initialLabelIds: initialLabelIds,
        )..add(const EditorStarted()),
      ),
      BlocProvider(
        create: (context) => AttachmentsCubit(
          AttachmentsApi(context.read<ApiNoteRepository>()),
          FileService(),
          noteId: noteId,
        ),
      ),
    ],
    child: const _NoteEditorView(),
  );
}

class _NoteEditorView extends StatefulWidget {
  const _NoteEditorView();

  @override
  State<_NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<_NoteEditorView> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  late final AppLifecycleListener _lifecycle;
  bool _attachmentsLoaded = false;
  EditorStatus? _shownStatus;

  NoteEditorBloc get _bloc => context.read<NoteEditorBloc>();

  @override
  void initState() {
    super.initState();
    // Hidden covers a closed or backgrounded browser tab, paused covers mobile.
    _lifecycle = AppLifecycleListener(onHide: _flush, onPause: _flush);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _flush() => _bloc.add(const EditorFlushRequested());

  void _close() {
    _flush();
    context.canPop() ? context.pop() : context.go(AppRoutes.notes);
  }

  /// Mirrors drafts loaded from the server into the text fields.
  void _sync(BuildContext context, NoteEditorState state) {
    if (_title.text != state.title) _setText(_title, state.title);
    if (_content.text != state.content) _setText(_content, state.content);
    if (state.existsOnServer && !_attachmentsLoaded) {
      _attachmentsLoaded = true;
      context.read<AttachmentsCubit>().load();
    }
    if (state.deleted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Note deleted.')));
      context.canPop() ? context.pop() : context.go(AppRoutes.notes);
    }
    if (state.status != _shownStatus) {
      _shownStatus = state.status;
      // Dialogs over a note that was just locked or taken away must not keep
      // showing its shares or summary.
      if (state.status == EditorStatus.locked ||
          state.status == EditorStatus.unavailable) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route is! PopupRoute);
      }
    }
  }

  static void _setText(TextEditingController controller, String text) =>
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

  Future<void> _pickLabels(NoteEditorState state) async {
    final labels = await showLabelPicker(
      context,
      selected: state.note!.labelIds,
    );
    if (labels != null) _bloc.add(EditorLabelsChanged(labels));
  }

  Future<void> _onAction(NoteEditorState state, EditorAction action) async {
    final note = state.note!.copyWith(title: state.title);
    switch (action) {
      case EditorAction.delete:
        if (await confirmDeleteNote(context, note)) {
          _bloc.add(const EditorDeleteRequested());
        }
      case EditorAction.share:
        _flush();
        await showShareDialog(context, note);
      case EditorAction.protection:
        _flush();
        final changed = await showProtectionPanel(context, note);
        if (changed && mounted) {
          _bloc.add(const EditorReloadRequested());
        }
      case EditorAction.summary:
        _flush();
        await showSummaryPanel(context, noteId: note.id, noteTitle: note.title);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<NoteEditorBloc, NoteEditorState>(
        listener: _sync,
        builder: (context, state) => PageShortcuts(
          // A new note focuses its title instead.
          autofocus: !_bloc.startsBlank,
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _close,
            const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                _flush,
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _flush,
          },
          child: PopScope(
            onPopInvokedWithResult: (_, _) => _flush(),
            child: Scaffold(
              // A desk-coloured page so the note's paper sheet stands out.
              backgroundColor: context.isExpanded
                  ? context.jotterColors.sidebar
                  : null,
              appBar: AppBar(
                backgroundColor: context.isExpanded
                    ? context.jotterColors.sidebar
                    : null,
                leading: BackButton(onPressed: _close),
                titleSpacing: 0,
                title: SaveStatusIndicator(
                  status: state.saveStatus,
                  error: state.saveError,
                  onRetry: _flush,
                ),
                actions: [
                  const UnverifiedBanner(compact: true),
                  if (state.status == EditorStatus.ready && state.note != null)
                    EditorActionBar(
                      note: state.note!,
                      existsOnServer: state.existsOnServer,
                      canEdit: state.canEdit,
                      onPin: () => _bloc.add(const EditorPinToggled()),
                      onLabels: () => _pickLabels(state),
                      onAttach: () => AttachmentSection.addFiles(context),
                      onAction: (action) => _onAction(state, action),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              body: SafeArea(top: false, child: _body(state)),
            ),
          ),
        ),
      );

  Widget _body(NoteEditorState state) => switch (state.status) {
    EditorStatus.loading => const LoadingView(label: 'Opening note'),
    EditorStatus.locked => LockedNoteView(
      title: state.note?.title ?? state.title,
      busy: state.unlocking,
      error: state.unlockError,
      onUnlock: (password) => _bloc.add(EditorUnlockRequested(password)),
    ),
    EditorStatus.unavailable => UnavailableNoteView(
      reason: state.unavailableReason ?? 'This note cannot be opened.',
      draft: state.isDirty ? '${state.title}\n\n${state.content}' : null,
      onBack: () => context.go(AppRoutes.notes),
    ),
    EditorStatus.ready => _Editor(
      state: state,
      title: _title,
      content: _content,
      onLabels: state.note?.isOwned ?? false ? () => _pickLabels(state) : null,
    ),
  };
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.state,
    required this.title,
    required this.content,
    this.onLabels,
  });

  final NoteEditorState state;
  final TextEditingController title;
  final TextEditingController content;
  final VoidCallback? onLabels;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NoteEditorBloc>();
    final palette = context.jotterColors;
    final fontSize = context.watch<PreferencesCubit>().state.noteFontSize;
    final labels = context.read<LabelStore>().labels;
    final readOnly = !state.canEdit;
    InputDecoration bare(String hint) => InputDecoration(
      hintText: hint,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      counterText: '',
      contentPadding: EdgeInsets.zero,
    );
    final compact = context.isCompact;
    final width = MediaQuery.sizeOf(context).width;
    // Desktop: the note sits on a sheet of paper; very wide windows add a
    // details column instead of leaving empty margins.
    final sheet = width >= 840;
    final panel = width >= 1180;
    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._notices(context),
        TextField(
          key: const Key('note-title'),
          controller: title,
          readOnly: readOnly,
          autofocus: state.isNew,
          maxLength: 200,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onChanged: (value) => bloc.add(EditorTitleChanged(value)),
          style: TextStyle(
            fontSize: compact ? 26 : 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
            height: 1.25,
          ),
          decoration: bare('Title').copyWith(
            hintStyle: TextStyle(
              fontSize: compact ? 26 : 32,
              fontWeight: FontWeight.w700,
              color: palette.muted.withValues(alpha: .55),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MetaRow(
          state: state,
          labels: labels,
          content: content,
          onLabels: readOnly ? null : onLabels,
          showWords: !panel,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1, color: palette.line),
        ),
        TextField(
          key: const Key('note-content'),
          controller: content,
          readOnly: readOnly,
          minLines: 8,
          maxLines: null,
          maxLength: 50000,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (value) => bloc.add(EditorContentChanged(value)),
          style: TextStyle(fontSize: fontSize, height: 1.7),
          decoration: bare(readOnly ? '' : 'Start writing…').copyWith(
            hintStyle: TextStyle(
              fontSize: fontSize,
              color: palette.muted.withValues(alpha: .7),
            ),
          ),
        ),
        if (state.existsOnServer) ...[
          const SizedBox(height: 36),
          AttachmentSection(canEdit: state.canEdit),
        ],
      ],
    );
    if (!sheet) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          compact ? 20 : 32,
          compact ? 12 : 28,
          compact ? 20 : 32,
          64,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: page,
          ),
        ),
      );
    }
    final paper = Container(
      constraints: const BoxConstraints(minHeight: 520),
      padding: const EdgeInsets.fromLTRB(52, 44, 52, 44),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line),
        boxShadow: palette.softShadow,
      ),
      child: page,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 64),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: panel ? 1140 : 860),
          child: panel
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: paper),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 284,
                      child: _DetailsPanel(
                        state: state,
                        labels: labels,
                        content: content,
                        onLabels: readOnly ? null : onLabels,
                      ),
                    ),
                  ],
                )
              : paper,
        ),
      ),
    );
  }

  List<Widget> _notices(BuildContext context) {
    final bloc = context.read<NoteEditorBloc>();
    final me = context.read<MeCubit>().state.account.displayName;
    final others = state.presence.where((name) => name != me).toList();
    Widget gap(Widget child) =>
        Padding(padding: const EdgeInsets.only(bottom: 14), child: child);
    return [
      if (others.isNotEmpty) gap(_Presence(names: others)),
      if (state.readOnlyReason == ReadOnlyReason.viewer)
        gap(
          const MessageStrip(
            'You can read this note but not edit it.',
            icon: Icons.visibility_outlined,
          ),
        ),
      if (state.readOnlyReason == ReadOnlyReason.permissionLost)
        gap(
          const MessageStrip(
            'The owner changed your access to view only. '
            'Copy any text you still need.',
            tone: JotterTone.warning,
          ),
        ),
      if (state.newerVersionAvailable)
        gap(
          MessageStrip(
            'Someone saved a newer version while you were typing.',
            tone: JotterTone.warning,
            icon: Icons.update_rounded,
            action: Wrap(
              children: [
                TextButton(
                  onPressed: () => bloc.add(const EditorReloadRequested()),
                  child: const Text('Show latest'),
                ),
                TextButton(
                  onPressed: () => bloc.add(const EditorKeepMineRequested()),
                  child: const Text('Keep mine'),
                ),
              ],
            ),
          ),
        ),
      if (state.saveStatus == SaveStatus.failed && state.saveError != null)
        gap(MessageStrip(state.saveError!, error: true)),
      if (state.note != null) _SyncConflictNotice(noteId: state.note!.id),
    ];
  }
}

/// Edits made offline can collide with a newer version from another device;
/// the sync sheet is where they are kept as a copy or discarded.
class _SyncConflictNotice extends StatelessWidget {
  const _SyncConflictNotice({required this.noteId});

  final String noteId;

  /// Once resolved, the editor shows the version that won on the server.
  Future<void> _review(BuildContext context) async {
    final store = context.read<NoteStore>();
    final editor = context.read<NoteEditorBloc>();
    await showSyncStatusSheet(context);
    if (!store.hasConflict(noteId)) editor.add(const EditorReloadRequested());
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SyncStatusCubit, WorkspaceSyncStatus>(
        builder: (context, _) {
          if (!context.read<NoteStore>().hasConflict(noteId)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: MessageStrip(
              'This note changed on another device while you were offline. '
              'Your version has not been lost.',
              error: true,
              icon: Icons.call_split_rounded,
              action: TextButton(
                onPressed: () => _review(context),
                child: const Text('Review'),
              ),
            ),
          );
        },
      );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.state,
    required this.labels,
    required this.content,
    this.onLabels,
    this.showWords = true,
  });

  final NoteEditorState state;
  final List<JotterLabel> labels;
  final TextEditingController content;
  final VoidCallback? onLabels;

  /// Off when the details column already shows the counts.
  final bool showWords;

  @override
  Widget build(BuildContext context) {
    final note = state.note!;
    final palette = context.jotterColors;
    final muted = palette.muted;
    final tags = labels.where((l) => note.labelIds.contains(l.id)).toList();
    Widget tag(String name) => Material(
      color: palette.ink.withValues(alpha: palette.dark ? .1 : .055),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onLabels,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label_outline_rounded, size: 13, color: muted),
              const SizedBox(width: 5),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: palette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Counts words as they are typed, without rebuilding the editor.
        ValueListenableBuilder(
          valueListenable: content,
          builder: (context, value, _) {
            final words = RegExp(r'\S+').allMatches(value.text).length;
            return Text(
              [
                state.isNew
                    ? 'New note'
                    : 'Edited ${relativeDate(note.updatedAt)}',
                if (words > 0 && showWords)
                  '$words ${words == 1 ? 'word' : 'words'}',
              ].join('  ·  '),
              style: TextStyle(fontSize: 13, color: muted),
            );
          },
        ),
        for (final label in tags) tag(label.name),
        if (tags.isEmpty && onLabels != null)
          TextButton.icon(
            onPressed: onLabels,
            style: TextButton.styleFrom(
              foregroundColor: muted,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(
                fontFamily: kJotterFont,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Add label'),
          ),
      ],
    );
  }
}

/// Who else has this note open, as a small stack of initials.
class _Presence extends StatelessWidget {
  const _Presence({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final shown = names.take(3).toList();
    return Semantics(
      label: 'Also here: ${names.join(', ')}',
      excludeSemantics: true,
      child: EntranceTransition(
        duration: JotterMotion.medium,
        child: Row(
          children: [
            SizedBox(
              width: 25.0 + (shown.length - 1) * 16,
              height: 25,
              child: Stack(
                children: [
                  for (final (index, name) in shown.indexed)
                    Positioned(
                      left: index * 16,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: palette.paper,
                          shape: BoxShape.circle,
                        ),
                        child: UserAvatar(name: name, radius: 11),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Also here: ${names.join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: palette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The right-hand column on wide screens: facts about the note, its labels
/// and its access, kept beside the text instead of empty margins.
class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.state,
    required this.labels,
    required this.content,
    this.onLabels,
  });

  final NoteEditorState state;
  final List<JotterLabel> labels;
  final TextEditingController content;
  final VoidCallback? onLabels;

  @override
  Widget build(BuildContext context) {
    final note = state.note!;
    final palette = context.jotterColors;
    final muted = palette.muted;
    final tags = labels.where((l) => note.labelIds.contains(l.id)).toList();
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
    );
    Widget fact(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13.5, color: muted)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    Widget card(List<Widget> children) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
    final access = note.isOwned
        ? ('Owner', Icons.verified_user_outlined)
        : state.canEdit
        ? ('Can edit', Icons.edit_outlined)
        : ('View only', Icons.visibility_outlined);
    return Column(
      children: [
        card([
          heading('Details'),
          fact(
            Icons.add_circle_outline_rounded,
            'Created',
            state.isNew ? 'Just now' : relativeDate(note.createdAt),
          ),
          fact(
            Icons.history_rounded,
            'Edited',
            state.isNew ? 'Just now' : relativeDate(note.updatedAt),
          ),
          ValueListenableBuilder(
            valueListenable: content,
            builder: (context, value, _) => Column(
              children: [
                fact(
                  Icons.notes_rounded,
                  'Words',
                  '${RegExp(r'\S+').allMatches(value.text).length}',
                ),
                fact(
                  Icons.text_fields_rounded,
                  'Characters',
                  '${value.text.characters.length}',
                ),
              ],
            ),
          ),
        ]),
        card([
          Row(
            children: [
              Expanded(child: heading('Labels')),
              if (onLabels != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onLabels,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'No labels yet.',
                style: TextStyle(fontSize: 13.5, color: muted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in tags)
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                      decoration: BoxDecoration(
                        color: palette.ink.withValues(
                          alpha: palette.dark ? .1 : .055,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.label_outline_rounded,
                            size: 13,
                            color: muted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            label.name,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ]),
        card([
          heading('Access'),
          fact(access.$2, 'You', access.$1),
          if (note.isPinned) fact(Icons.push_pin_outlined, 'Pinned', 'Yes'),
          fact(
            Icons.people_outline_rounded,
            'Shared',
            note.isShared || !note.isOwned ? 'Yes' : 'No',
          ),
          fact(
            Icons.lock_outline_rounded,
            'Password',
            note.isProtected ? 'On' : 'Off',
          ),
        ]),
      ],
    );
  }
}
