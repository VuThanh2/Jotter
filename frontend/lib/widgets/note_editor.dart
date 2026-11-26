import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/note_repository.dart';
import '../models/jotter_label.dart';
import '../models/jotter_note.dart';
import '../theme.dart';

Future<JotterNote?> showNoteEditor(
  BuildContext context, {
  required JotterNote note,
  required List<JotterLabel> labels,
  required Future<JotterNote> Function(JotterNote) onSave,
  Future<JotterNote> Function(JotterNote)? onSaveCopy,
  Future<void> Function(JotterNote)? onCompare,
  ValueListenable<Map<String, dynamic>?>? updates,
  double noteFontSize = 16,
}) => showDialog<JotterNote>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _NoteEditor(
    note: note,
    labels: labels,
    onSave: onSave,
    onSaveCopy: onSaveCopy,
    onCompare: onCompare,
    updates: updates,
    noteFontSize: noteFontSize,
  ),
);

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({
    required this.note,
    required this.labels,
    required this.onSave,
    this.onSaveCopy,
    this.onCompare,
    this.updates,
    this.noteFontSize = 16,
  });
  final JotterNote note;
  final List<JotterLabel> labels;
  final Future<JotterNote> Function(JotterNote) onSave;
  final Future<JotterNote> Function(JotterNote)? onSaveCopy;
  final Future<void> Function(JotterNote)? onCompare;
  final ValueListenable<Map<String, dynamic>?>? updates;
  final double noteFontSize;
  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  final _contentFocus = FocusNode();
  final _scroll = ScrollController();
  bool _saving = false;
  bool _comparing = false;
  bool _allowPop = false;
  bool _confirmingClose = false;
  bool _permissionLost = false;
  bool _accessRevoked = false;
  bool _masked = false;
  bool _remoteChanged = false;
  bool _versionConflict = false;
  String? _error;
  String? _notice;
  List<String> _presence = [];

  bool get _dirty =>
      _title.text != widget.note.title || _content.text != widget.note.content;
  bool get _hasContent =>
      _title.text.trim().isNotEmpty || _content.text.trim().isNotEmpty;
  bool get _canEdit =>
      widget.note.canEdit && !_permissionLost && !_accessRevoked && !_masked;
  bool get _canCopy =>
      widget.note.canEdit &&
      widget.onSaveCopy != null &&
      !_masked &&
      !widget.note.isProtected;
  JotterNote get _draft =>
      widget.note.copyWith(title: _title.text, content: _content.text);
  int get _wordCount => _content.text.trim().isEmpty
      ? 0
      : _content.text.trim().split(RegExp(r'\s+')).length;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note.title)
      ..addListener(_onChanged);
    _content = TextEditingController(text: widget.note.content)
      ..addListener(_onChanged);
    widget.updates?.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(covariant _NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updates != widget.updates) {
      oldWidget.updates?.removeListener(_onUpdate);
      widget.updates?.addListener(_onUpdate);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onUpdate() {
    final event = widget.updates?.value;
    if (!mounted || event == null || event['noteId'] != widget.note.id) return;
    setState(() {
      switch (event['type']) {
        case 'presence':
          _presence = (event['users'] as List? ?? [])
              .whereType<Map>()
              .map((user) => user['displayName']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();
        case 'noteChanged':
          final version = event['version'];
          if (version is num && version > widget.note.version) {
            _remoteChanged = true;
          }
          if (event['isProtected'] == true) {
            _masked = true;
            _accessRevoked = true;
          }
        case 'permissionChanged':
          final permission = event['permission'];
          if (permission == 'ReadOnly') _permissionLost = true;
          if (permission == 'Edit' || permission == 'Owner') {
            _permissionLost = false;
          }
        case 'accessRevoked':
          _accessRevoked = true;
          _masked = widget.note.isProtected || event['isProtected'] == true;
      }
    });
    if (_masked || _permissionLost || _accessRevoked) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    widget.updates?.removeListener(_onUpdate);
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _save() => _persist(widget.onSave);
  Future<void> _saveCopy() async {
    if (_canCopy) await _persist(widget.onSaveCopy!, copy: true);
  }

  Future<void> _persist(
    Future<JotterNote> Function(JotterNote) save, {
    bool copy = false,
  }) async {
    if (_saving ||
        _comparing ||
        !_hasContent ||
        (copy ? !_canCopy : !_canEdit)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await save(_draft);
      if (!mounted) return;
      if (!copy && (_accessRevoked || _permissionLost || _masked)) {
        setState(() {
          _saving = false;
          _notice = 'Your access changed while saving. Reopen the note to check its latest state.';
        });
        return;
      }
      setState(() => _allowPop = true);
      Navigator.pop(context, saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
        _versionConflict =
            error is RepositoryException && error.code == 'VersionConflict';
        if (error is RepositoryException && error.statusCode == 403) {
          _permissionLost = true;
        }
        if (error is RepositoryException && error.statusCode == 423) {
          _accessRevoked = true;
          _masked = true;
        }
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  Future<void> _compare() async {
    if (_saving ||
        _comparing ||
        _masked ||
        _accessRevoked ||
        widget.onCompare == null) {
      return;
    }
    setState(() => _comparing = true);
    try {
      await widget.onCompare!(_draft);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _comparing = false);
    }
  }

  Future<void> _copyDraft() async {
    if (_masked || !widget.note.canEdit) return;
    await Clipboard.setData(
      ClipboardData(text: '${_title.text}\n\n${_content.text}'),
    );
    if (mounted) setState(() => _notice = 'Draft copied to the clipboard.');
  }

  Future<void> _requestClose() async {
    if (_saving || _comparing || _confirmingClose) return;
    if (_dirty && widget.note.canEdit && !_masked) {
      _confirmingClose = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep your changes?'),
          content: const Text(
            'This note has unsaved changes. You can keep editing or discard them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      _confirmingClose = false;
      if (!mounted || discard != true) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  void _insert(String prefix) {
    if (_saving || !_canEdit) return;
    final value = _content.value;
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final end = value.selection.isValid
        ? value.selection.end
        : value.text.length;
    final insertion =
        '${start > 0 && value.text[start - 1] != '\n' ? '\n' : ''}$prefix';
    if (value.text.length - (end - start) + insertion.length > 50000) return;
    _content.value = TextEditingValue(
      text: value.text.replaceRange(start, end, insertion),
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
    _contentFocus.requestFocus();
  }

  String _date(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final colors = context.jotterColors;
    final scheme = Theme.of(context).colorScheme;
    final selectedLabels = widget.labels.where(
      (label) => widget.note.labelIds.contains(label.id),
    );
    final impaired = _permissionLost || _accessRevoked;
    return PopScope<JotterNote>(
      canPop: _allowPop || (!_dirty && !_saving && !_comparing),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
          const SingleActivator(LogicalKeyboardKey.escape): _requestClose,
        },
        child: Focus(
          autofocus: true,
          child: Dialog(
            backgroundColor: colors.paper,
            surfaceTintColor: Colors.transparent,
            insetPadding: EdgeInsets.all(compact ? 10 : 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 16 : 24),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 860),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 20 : 32,
                        18,
                        12,
                        18,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.note.canEdit ? 'YOUR NOTE' : 'SHARED NOTE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                          if (!_canEdit && !_masked)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: _EditorBadge(
                                icon: Icons.visibility_outlined,
                                label: 'Read only',
                              ),
                            ),
                          IconButton(
                            tooltip: 'Close note',
                            onPressed: _saving || _comparing
                                ? null
                                : _requestClose,
                            icon: const Icon(Icons.close, size: 21),
                            color: colors.muted,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.line),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(
                          compact ? 24 : 48,
                          compact ? 28 : 40,
                          compact ? 24 : 48,
                          28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_presence.isNotEmpty && !_masked)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 17,
                                      color: colors.muted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Here now: ${_presence.join(', ')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_notice != null) _banner(_notice!),
                            if (_remoteChanged && !_masked && !_accessRevoked)
                              _banner(
                                'This note has a newer saved version. Your draft has been kept.',
                                actions: [
                                  if (widget.onCompare != null)
                                    TextButton(
                                      key: const Key('compare-note-version'),
                                      onPressed: _saving || _comparing
                                          ? null
                                          : _compare,
                                      child: const Text(
                                        'Compare saved version',
                                      ),
                                    ),
                                ],
                              ),
                            if (impaired && !_masked)
                              _banner(
                                _accessRevoked
                                    ? 'Your access to this note was removed. Your draft is still here, but the original can no longer be saved.'
                                    : 'This note is now view only. Your draft is still here, but the original can no longer be saved.',
                                actions: [
                                  if (_canCopy)
                                    TextButton(
                                      key: const Key('save-note-copy'),
                                      onPressed: _saving ? null : _saveCopy,
                                      child: const Text('Save a copy'),
                                    ),
                                  if (widget.note.canEdit)
                                    TextButton(
                                      key: const Key('copy-draft'),
                                      onPressed: _saving ? null : _copyDraft,
                                      child: const Text('Copy draft'),
                                    ),
                                ],
                              ),
                            if (_error != null && !_masked)
                              _banner(
                                _error!,
                                error: true,
                                actions: [
                                  if (_canCopy && !impaired)
                                    TextButton(
                                      key: const Key('save-note-copy'),
                                      onPressed: _saving ? null : _saveCopy,
                                      child: const Text('Save a copy'),
                                    ),
                                  if (_versionConflict &&
                                      !_remoteChanged &&
                                      widget.onCompare != null &&
                                      !_accessRevoked)
                                    TextButton(
                                      key: const Key('compare-note-version'),
                                      onPressed: _saving || _comparing
                                          ? null
                                          : _compare,
                                      child: const Text(
                                        'Compare saved version',
                                      ),
                                    ),
                                ],
                              ),
                            if (_masked)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 50,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 42,
                                      color: colors.muted,
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'This note is no longer available in this session.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Close the editor and unlock or reopen the note to check your access.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              Semantics(
                                label: 'Note title',
                                child: TextField(
                                  key: const Key('note-title'),
                                  controller: _title,
                                  readOnly: !_canEdit || _saving || _comparing,
                                  maxLength: 200,
                                  maxLines: null,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: compact ? 28 : 36,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Untitled note',
                                    hintStyle: TextStyle(color: colors.muted),
                                    counterText: '',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Updated ${_date(widget.note.updatedAt)}',
                                    style: TextStyle(
                                      color: colors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (widget.note.isProtected)
                                    const _EditorBadge(
                                      icon: Icons.lock_open_outlined,
                                      label: 'Protected',
                                    ),
                                  for (final label in selectedLabels)
                                    _EditorBadge(
                                      icon: Icons.label_outline,
                                      label: label.name,
                                    ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 26,
                                ),
                                child: Divider(height: 1, color: colors.line),
                              ),
                              Semantics(
                                label: 'Note content',
                                child: TextField(
                                  key: const Key('note-content'),
                                  controller: _content,
                                  focusNode: _contentFocus,
                                  readOnly: !_canEdit || _saving || _comparing,
                                  minLines: 10,
                                  maxLines: null,
                                  maxLength: 50000,
                                  keyboardType: TextInputType.multiline,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: TextStyle(
                                    color: colors.ink,
                                    fontSize: widget.noteFontSize
                                        .clamp(12, 32)
                                        .toDouble(),
                                    height: 1.85,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _canEdit
                                        ? 'A little space for your next thought…'
                                        : 'This note has no content.',
                                    hintStyle: TextStyle(color: colors.muted),
                                    counterText: '',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: colors.line),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 16 : 28,
                        vertical: 16,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final tools = Row(
                            children: [
                              if (_canEdit) ...[
                                IconButton(
                                  tooltip: 'Insert bullet',
                                  onPressed: _saving || _comparing
                                      ? null
                                      : () => _insert('• '),
                                  icon: const Icon(
                                    Icons.format_list_bulleted,
                                    size: 20,
                                  ),
                                  color: colors.muted,
                                ),
                                IconButton(
                                  tooltip: 'Insert checklist item',
                                  onPressed: _saving || _comparing
                                      ? null
                                      : () => _insert('☐ '),
                                  icon: const Icon(
                                    Icons.checklist_outlined,
                                    size: 20,
                                  ),
                                  color: colors.muted,
                                ),
                                if (!compact) const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
                                  _masked
                                      ? 'Content hidden'
                                      : '$_wordCount ${_wordCount == 1 ? 'word' : 'words'}',
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          );
                          final Widget action =
                              widget.note.canEdit && !impaired && !_masked
                              ? FilledButton.icon(
                                  key: const Key('save-note'),
                                  onPressed:
                                      _saving ||
                                          _comparing ||
                                          !_hasContent ||
                                          !_canEdit
                                      ? null
                                      : _save,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check, size: 18),
                                  label: Text(
                                    _saving ? 'Saving…' : 'Save note',
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: _saving || _comparing
                                      ? null
                                      : _requestClose,
                                  child: const Text('Done'),
                                );
                          if (constraints.maxWidth < 330) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                tools,
                                const SizedBox(height: 8),
                                action,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: tools),
                              const SizedBox(width: 16),
                              action,
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner(
    String text, {
    List<Widget> actions = const [],
    bool error = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error
            ? scheme.errorContainer
            : scheme.primaryContainer.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: error ? scheme.onErrorContainer : scheme.onSurface,
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Wrap(spacing: 5, runSpacing: 4, children: actions),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorBadge extends StatelessWidget {
  const _EditorBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 180),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: context.jotterColors.sidebar,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.jotterColors.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.jotterColors.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );
}
