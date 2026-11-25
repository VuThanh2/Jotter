import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_label.dart';
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
import 'package:jotter/modules/protection/unlock/locked_note_view.dart';
import 'package:jotter/shared/lib/file_service.dart';
import 'package:jotter/shared/widgets/note_card.dart';
import 'package:jotter/shared/widgets/state_views.dart';
import 'package:jotter/widgets/note_details_dialog.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note deleted.')));
      context.canPop() ? context.pop() : context.go(AppRoutes.notes);
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
    final note = state.note!;
    if (action == EditorAction.delete) {
      if (await confirmDeleteNote(context, note)) {
        _bloc.add(const EditorDeleteRequested());
      }
      return;
    }
    _flush();
    final changed = await showNoteDetailsDialog(
      context,
      repository: context.read<ApiNoteRepository>(),
      note: note.copyWith(title: state.title, content: state.content),
      initialTab: switch (action) {
        EditorAction.share => 'Sharing',
        EditorAction.protection => 'Protection',
        _ => 'Summary',
      },
    );
    if (changed == true) _bloc.add(const EditorReloadRequested());
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<NoteEditorBloc, NoteEditorState>(
        listener: _sync,
        builder: (context, state) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _close,
            const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                _flush,
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _flush,
          },
          child: PopScope(
            onPopInvokedWithResult: (_, _) => _flush(),
            child: Scaffold(
              appBar: AppBar(
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
    ),
  };
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.state,
    required this.title,
    required this.content,
  });

  final NoteEditorState state;
  final TextEditingController title;
  final TextEditingController content;

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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
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
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
                decoration: bare('Title'),
              ),
              const SizedBox(height: 10),
              _MetaRow(state: state, labels: labels),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
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
                decoration: bare(readOnly ? '' : 'Start writing…'),
              ),
              if (state.existsOnServer) ...[
                const SizedBox(height: 32),
                AttachmentSection(canEdit: state.canEdit),
              ],
            ],
          ),
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
      if (others.isNotEmpty)
        gap(
          Row(
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 16,
                color: context.jotterColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Also here: ${others.join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.jotterColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      if (state.readOnlyReason == ReadOnlyReason.viewer)
        gap(const MessageStrip('You can read this note but not edit it.')),
      if (state.readOnlyReason == ReadOnlyReason.permissionLost)
        gap(
          const MessageStrip(
            'The owner changed your access to view only. '
            'Copy any text you still need.',
          ),
        ),
      if (state.newerVersionAvailable)
        gap(
          MessageStrip(
            'Someone saved a newer version while you were typing.',
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
    ];
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.state, required this.labels});

  final NoteEditorState state;
  final List<JotterLabel> labels;

  @override
  Widget build(BuildContext context) {
    final note = state.note!;
    final muted = context.jotterColors.muted;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          state.isNew ? 'New note' : 'Edited ${relativeDate(note.updatedAt)}',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        for (final label in labels.where((l) => note.labelIds.contains(l.id)))
          Chip(
            avatar: Icon(Icons.label_outline_rounded, size: 14, color: muted),
            label: Text(label.name),
            visualDensity: VisualDensity.compact,
            labelStyle: const TextStyle(fontSize: 11),
          ),
      ],
    );
  }
}
