import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/api_note_repository.dart';
import '../data/note_features_api.dart';
import '../data/note_repository.dart';
import '../models/jotter_note.dart';
import '../models/note_features.dart';
import '../platform/file_transfer.dart';

Future<bool?> showNoteDetailsDialog(
  BuildContext context, {
  required ApiNoteRepository repository,
  required JotterNote note,
  String initialTab = 'Files',
  ValueListenable<Map<String, dynamic>?>? updates,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _NoteDetails(
    repository: repository,
    note: note,
    initialTab: initialTab,
    updates: updates,
  ),
);

class _NoteDetails extends StatefulWidget {
  const _NoteDetails({
    required this.repository,
    required this.note,
    required this.initialTab,
    this.updates,
  });
  final ApiNoteRepository repository;
  final JotterNote note;
  final String initialTab;
  final ValueListenable<Map<String, dynamic>?>? updates;
  @override
  State<_NoteDetails> createState() => _NoteDetailsState();
}

class _NoteDetailsState extends State<_NoteDetails> {
  static const _tabs = ['Files', 'Sharing', 'Protection', 'Summary'];
  final _emails = TextEditingController();
  String _permission = 'ReadOnly';
  late String _tab;
  late bool _protected;
  late bool _locked;
  bool _busy = false;
  bool _loading = true;
  bool _changed = false;
  String? _error;
  String? _notice;
  List<NoteAttachment> _files = [];
  List<NoteShare> _shares = [];
  NoteSummary? _summary;
  String _generated = '';
  bool _generatedSaved = false;
  bool _generating = false;
  bool _accessDenied = false;
  bool _permissionLost = false;
  int _accessGeneration = 0;
  final _privateContentInvalidated = ValueNotifier<bool>(false);
  bool get _canEdit =>
      widget.note.canEdit && !_permissionLost && !_accessDenied;
  StreamSubscription<SummaryEvent>? _summarySubscription;

  ApiNoteRepository get _api => widget.repository;
  String get _id => widget.note.id;

  @override
  void initState() {
    super.initState();
    _tab = _tabs.contains(widget.initialTab) ? widget.initialTab : 'Files';
    _protected = widget.note.isProtected;
    _locked = _protected && !widget.note.contentLoaded;
    widget.updates?.addListener(_onUpdate);
    _loadTab();
  }

  void _onUpdate() {
    final event = widget.updates?.value;
    if (!mounted || event == null || event['noteId'] != _id) return;
    if (event['type'] == 'permissionChanged') {
      setState(() => _permissionLost = event['permission'] == 'ReadOnly');
      return;
    }
    if (event['type'] != 'accessRevoked' && event['isProtected'] != true) {
      return;
    }
    _accessGeneration++;
    _privateContentInvalidated.value = true;
    _summarySubscription?.cancel();
    setState(() {
      _accessDenied = event['isProtected'] != true;
      if (event['isProtected'] == true) {
        _protected = true;
        _locked = true;
      }
      _files = [];
      _shares = [];
      _summary = null;
      _generated = '';
      _generating = false;
      _error = _accessDenied
          ? 'Your access to this note was removed. Close this window to return to your workspace.'
          : 'This note was protected. Unlock it again to view its files and summary.';
    });
  }

  @override
  void dispose() {
    widget.updates?.removeListener(_onUpdate);
    _privateContentInvalidated.dispose();
    _emails.dispose();
    _summarySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTab() async {
    final tab = _tab;
    final generation = _accessGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_accessDenied || (_locked && tab != 'Protection')) return;
      if (tab == 'Files') {
        final files = await _api.listAttachments(_id);
        if (mounted && _tab == tab && generation == _accessGeneration) {
          setState(() => _files = files);
        }
      }
      if (tab == 'Sharing' && widget.note.isOwned) {
        final shares = await _api.listShares(_id);
        if (mounted && _tab == tab && generation == _accessGeneration) {
          setState(() => _shares = shares);
        }
      }
      if (tab == 'Summary') {
        final summary = await _api.getSummary(_id);
        if (mounted && _tab == tab && generation == _accessGeneration) {
          setState(() {
            _summary = summary;
            _generated = summary?.text ?? '';
            _generatedSaved = summary != null;
          });
        }
      }
    } catch (error) {
      if (mounted && _tab == tab) {
        setState(() {
          _error = _message(error);
          if (error is RepositoryException && error.statusCode == 423) {
            _locked = true;
          }
        });
      }
    } finally {
      if (mounted && _tab == tab) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is RepositoryException
      ? error.message
      : 'Could not complete this action. Please try again.';

  Future<void> _run(
    Future<void> Function() action, {
    String? success,
    bool changes = true,
  }) async {
    if (_busy || _generating || _accessDenied) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _changed = _changed || changes;
        if (success != null) _notice = success;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          if (error is RepositoryException && error.statusCode == 423) {
            _locked = true;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    await _run(() async {
      final file = await openFile();
      if (file == null) return;
      if (await file.length() > maxAttachmentBytes) {
        throw const RepositoryException(
          'Each attachment must be 25 MB or smaller.',
        );
      }
      final bytes = await file.readAsBytes();
      await _api.attachFile(_id, bytes, file.name);
      _changed = true;
      final files = await _api.listAttachments(_id);
      if (mounted) setState(() => _files = files);
    }, changes: false);
  }

  Future<void> _fileAction(NoteAttachment file, {bool preview = false}) async {
    await _run(() async {
      final generation = _accessGeneration;
      final bytes = await _api.attachmentBytes(file.id);
      if (!mounted ||
          generation != _accessGeneration ||
          _locked ||
          _accessDenied) {
        return;
      }
      _privateContentInvalidated.value = false;
      if (preview && file.isImage) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
              child: ValueListenableBuilder<bool>(
                valueListenable: _privateContentInvalidated,
                builder: (context, invalid, _) => invalid
                    ? Column(
                        children: [
                          const Expanded(
                            child: Center(
                              child: Text(
                                'This image is no longer available in this session.',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close preview'),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    file.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Close preview',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: InteractiveViewer(
                              child: Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'This image cannot be previewed. You can still download it.',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await saveBytes(
                                    bytes,
                                    file.name,
                                    mimeType: file.mimeType,
                                  );
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_message(error))),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Download image'),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      } else {
        await saveBytes(bytes, file.name, mimeType: file.mimeType);
      }
    }, changes: false);
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _removeFile(NoteAttachment file) async {
    if (!await _confirm(
      'Remove attachment?',
      '“${file.name}” will be removed from this note.',
      'Remove',
    )) {
      return;
    }
    await _run(() async {
      await _api.removeAttachment(file.id);
      if (mounted) {
        setState(() => _files.removeWhere((item) => item.id == file.id));
      }
    }, success: 'Attachment removed.');
  }

  Future<void> _invite() async {
    final emails = _emails.text
        .split(RegExp(r'[,;\s]+'))
        .where((value) => value.isNotEmpty)
        .toList();
    await _run(() async {
      final result = await _api.inviteToNote(_id, emails, _permission);
      if (result.created > 0) _changed = true;
      final shares = await _api.listShares(_id);
      if (!mounted) return;
      setState(() {
        _shares = shares;
        _notice =
            '${result.created} ${result.created == 1 ? 'person invited' : 'people invited'}.${result.rejected.isNotEmpty ? '\n${result.rejected.map((item) => '${item.email}: ${_rejection(item.code)}').join('\n')}' : ''}';
        _emails.text = result.rejected.map((item) => item.email).join(', ');
      });
    }, changes: false);
  }

  String _rejection(String code) => switch (code) {
    'RecipientNotRegistered' => 'No registered account with this email.',
    'DuplicateShare' => 'Already has access.',
    'CannotShareWithSelf' => 'This is your own account.',
    _ => code,
  };

  Future<void> _changeShare(NoteShare share, String value) async =>
      _run(() async {
        await _api.changeSharePermission(_id, share.id, value);
        final shares = await _api.listShares(_id);
        if (mounted) setState(() => _shares = shares);
      }, success: 'Permission updated.');

  Future<void> _revoke(NoteShare share) async {
    if (!await _confirm(
      'Remove access?',
      '${share.email} will no longer be able to open this note.',
      'Remove access',
    )) {
      return;
    }
    await _run(() async {
      await _api.revokeShare(_id, share.id);
      if (mounted) {
        setState(() => _shares.removeWhere((item) => item.id == share.id));
      }
    }, success: 'Access removed.');
  }

  Future<List<String>?> _passwords(
    String title,
    List<String> labels, {
    bool newPassword = false,
  }) async {
    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordPrompt(
        title: title,
        labels: labels,
        newPassword: newPassword,
      ),
    );
  }

  Future<void> _unlock() async {
    final values = await _passwords('Unlock this note', ['Note password']);
    if (values == null) return;
    await _run(
      () async {
        await _api.unlockNote(_id, values[0]);
        if (mounted) setState(() => _locked = false);
        await _loadTab();
      },
      changes: false,
      success: 'Note unlocked for this session.',
    );
  }

  Future<void> _enableProtection() async {
    final values = await _passwords('Protect this note', [
      'New note password',
      'Confirm password',
    ], newPassword: true);
    if (values == null) return;
    await _run(() async {
      await _api.enableProtection(_id, values[0], values[1]);
      if (mounted) {
        setState(() {
          _protected = true;
          _locked = true;
        });
      }
    }, success: 'Protection enabled. The note is now locked.');
  }

  Future<void> _changePassword() async {
    final values = await _passwords('Change note password', [
      'Current password',
      'New note password',
      'Confirm password',
    ], newPassword: true);
    if (values == null) return;
    await _run(() async {
      await _api.changeNotePassword(_id, values[0], values[1], values[2]);
      if (mounted) setState(() => _locked = true);
    }, success: 'Password changed. All devices must unlock the note again.');
  }

  Future<void> _disableProtection() async {
    final values = await _passwords('Remove note protection', [
      'Current password',
    ]);
    if (values == null) return;
    if (!mounted ||
        !await _confirm(
          'Remove protection?',
          'Anyone with access to this note will be able to read it without its note password.',
          'Remove protection',
        )) {
      return;
    }
    await _run(() async {
      await _api.disableProtection(_id, values[0]);
      if (mounted) {
        setState(() {
          _protected = false;
          _locked = false;
        });
      }
    }, success: 'Note protection removed.');
  }

  Future<void> _relock() async => _run(() async {
    await _api.relockNote(_id);
    if (mounted) setState(() => _locked = true);
  }, success: 'Note locked on this session.');

  void _generate() {
    if (_busy || _generating || _accessDenied || _locked) return;
    setState(() {
      _generating = true;
      _generated = '';
      _generatedSaved = false;
      _error = null;
      _notice = null;
    });
    _summarySubscription = _api
        .generateSummary(_id)
        .listen(
          (event) {
            if (!mounted) return;
            setState(() {
              if (event.kind == 'delta') _generated += event.text;
              if (event.kind == 'completed') {
                _generated = event.text;
                _generatedSaved = true;
                _summary = NoteSummary(event.text, event.generatedAt!);
                _notice = 'Summary saved.';
                _changed = true;
              }
              if (event.kind == 'failed') _error = event.message;
            });
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _error = _message(error);
                _generating = false;
              });
            }
          },
          onDone: () {
            if (mounted) setState(() => _generating = false);
          },
        );
  }

  Future<void> _cancelSummary() async {
    await _summarySubscription?.cancel();
    if (mounted) {
      setState(() {
        _generating = false;
        _notice = 'Generation stopped. Only completed summaries are saved.';
      });
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    await _summarySubscription?.cancel();
    if (mounted) Navigator.pop(context, _changed);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Dialog(
        insetPadding: EdgeInsets.all(narrow ? 10 : 28),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 10, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Note details',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              widget.note.title.isEmpty
                                  ? 'Untitled note'
                                  : widget.note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close note details',
                        onPressed: _busy ? null : _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: _tabs
                        .map(
                          (tab) => Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(tab),
                              selected: _tab == tab,
                              onSelected: _busy || _generating
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _tab = tab;
                                        _notice = null;
                                      });
                                      _loadTab();
                                    },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                if (_busy || _loading)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(narrow ? 18 : 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) _banner(_error!, error: true),
                        if (_notice != null) _banner(_notice!),
                        if (_accessDenied)
                          const Text(
                            'Access to this note is no longer available.',
                          )
                        else if (_locked && _tab != 'Protection')
                          _lockedContent()
                        else if (_tab == 'Files')
                          _filesContent()
                        else if (_tab == 'Sharing')
                          _sharesContent()
                        else if (_tab == 'Protection')
                          _protectionContent()
                        else
                          _summaryContent(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, {bool error = false}) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: .35),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: error ? Theme.of(context).colorScheme.onErrorContainer : null,
        ),
      ),
    ),
  );
  Widget _lockedContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.lock_outline, size: 35),
      const SizedBox(height: 14),
      Text(
        'A little privacy for this thought.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Unlock this note to access its files, sharing settings, and summary.',
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _busy ? null : _unlock,
        icon: const Icon(Icons.lock_open_outlined),
        label: const Text('Unlock note'),
      ),
    ],
  );

  Widget _filesContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Everything that belongs with this note.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Attach documents, images, audio, or other files up to 25 MB each. Executable files are not supported.',
      ),
      const SizedBox(height: 18),
      if (_canEdit)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('Attach a file'),
          ),
        )
      else
        const Text(
          'You have view-only access. You can preview and download files.',
        ),
      const SizedBox(height: 22),
      if (_files.isEmpty && !_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 25),
          child: Text(
            'No attachments yet. A file added here stays with the note.',
          ),
        ),
      for (final file in _files)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      file.isImage
                          ? Icons.image_outlined
                          : Icons.insert_drive_file_outlined,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${file.sizeLabel} · ${file.mimeType}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (file.isImage)
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _fileAction(file, preview: true),
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: const Text('Preview'),
                      ),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _fileAction(file),
                      icon: const Icon(Icons.download_outlined, size: 17),
                      label: const Text('Download'),
                    ),
                    if (_canEdit)
                      TextButton.icon(
                        onPressed: _busy ? null : () => _removeFile(file),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text('Remove'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (!_loading)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : _loadTab,
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text('Refresh files'),
          ),
        ),
    ],
  );

  Widget _sharesContent() {
    if (!widget.note.isOwned) {
      return const Text(
        'Only the owner can invite people or manage access. You can read this note and edit it if the owner has granted editing access.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Good ideas are better together.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Invite registered Jotter accounts. Add up to 20 email addresses, separated by commas. Note passwords are never included in invitations.',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _emails,
          enabled: !_busy,
          minLines: 1,
          maxLines: 3,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email addresses',
            hintText: 'friend@example.com',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                initialValue: _permission,
                decoration: const InputDecoration(labelText: 'Permission'),
                items: const [
                  DropdownMenuItem(value: 'ReadOnly', child: Text('Can view')),
                  DropdownMenuItem(value: 'Edit', child: Text('Can edit')),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _permission = value!),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _invite,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Send invitation'),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          'People with access',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (_shares.isEmpty && !_loading)
          const Text('Only you have access to this note.'),
        for (final share in _shares)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    share.displayName.isEmpty ? share.email : share.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (share.displayName.isNotEmpty)
                    Text(
                      share.email,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('${share.id}:${share.permission}'),
                          initialValue: share.permission,
                          decoration: const InputDecoration(isDense: true),
                          items: const [
                            DropdownMenuItem(
                              value: 'ReadOnly',
                              child: Text('Can view'),
                            ),
                            DropdownMenuItem(
                              value: 'Edit',
                              child: Text('Can edit'),
                            ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) {
                                  if (value != null &&
                                      value != share.permission) {
                                    _changeShare(share, value);
                                  }
                                },
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _revoke(share),
                        child: const Text('Remove access'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : _loadTab,
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text('Refresh sharing'),
          ),
        ),
      ],
    );
  }

  Widget _protectionContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        _protected ? Icons.lock_outline : Icons.lock_open_outlined,
        size: 38,
      ),
      const SizedBox(height: 16),
      Text(
        _protected
            ? 'Protected with a note password.'
            : 'A little privacy, when you need it.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 10),
      Text(
        _protected
            ? (_locked
                  ? 'This note is locked in this session.'
                  : 'This note is unlocked in this session. You can lock it again at any time.')
            : 'Add a separate password to this note. Anyone opening it, including people it is shared with, will need that password.',
      ),
      const SizedBox(height: 20),
      if (_protected)
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            if (_locked)
              FilledButton.icon(
                onPressed: _busy ? null : _unlock,
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Unlock note'),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : _relock,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Lock now'),
              ),
            if (widget.note.isOwned)
              OutlinedButton(
                onPressed: _busy ? null : _changePassword,
                child: const Text('Change password'),
              ),
            if (widget.note.isOwned)
              TextButton(
                onPressed: _busy ? null : _disableProtection,
                child: const Text('Remove protection'),
              ),
          ],
        )
      else if (widget.note.isOwned)
        FilledButton.icon(
          onPressed: _busy ? null : _enableProtection,
          icon: const Icon(Icons.lock_outline, size: 18),
          label: const Text('Protect note'),
        ),
      if (!widget.note.isOwned)
        const Padding(
          padding: EdgeInsets.only(top: 18),
          child: Text(
            'Only the owner can add, change, or remove the note password.',
          ),
        ),
    ],
  );

  Widget _summaryContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'The thought, a little clearer.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Generate a concise summary from this note. AI can make mistakes; check the original before relying on the result.',
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: _busy || _generating ? null : _generate,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(
              _summary == null ? 'Generate summary' : 'Generate again',
            ),
          ),
          if (_generating)
            OutlinedButton(
              onPressed: _cancelSummary,
              child: const Text('Stop generation'),
            ),
          if (!_generating)
            TextButton(
              onPressed: _busy ? null : _loadTab,
              child: const Text('Load saved summary'),
            ),
        ],
      ),
      if (_generating)
        const Padding(
          padding: EdgeInsets.only(top: 20),
          child: LinearProgressIndicator(),
        ),
      const SizedBox(height: 22),
      if (_generated.isNotEmpty && !_generatedSaved && !_generating)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Incomplete preview · not saved',
            style: TextStyle(fontSize: 12),
          ),
        ),
      if (_generated.isNotEmpty)
        SelectableText(_generated, style: Theme.of(context).textTheme.bodyLarge)
      else if (!_loading)
        Text(
          _generating
              ? 'Making room for the main ideas…'
              : 'No summary yet. Generate one to keep the main points close.',
        ),
      if (_summary != null && _generatedSaved && !_generating)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(
            'Saved ${_summary!.generatedAt.toLocal().toString().split('.').first}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  );
}

class _PasswordPrompt extends StatefulWidget {
  const _PasswordPrompt({
    required this.title,
    required this.labels,
    required this.newPassword,
  });
  final String title;
  final List<String> labels;
  final bool newPassword;
  @override
  State<_PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<_PasswordPrompt> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers = List.generate(
    widget.labels.length,
    (_) => TextEditingController(),
  );
  bool _obscure = true;
  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.newPassword)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Text(
                    'Use 4–128 characters. Keep this password somewhere safe.',
                  ),
                ),
              for (var index = 0; index < widget.labels.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: _controllers[index],
                    obscureText: _obscure,
                    autofocus: index == 0,
                    maxLength: 128,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: widget.labels[index],
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter ${widget.labels[index].toLowerCase()}.';
                      }
                      if (widget.newPassword &&
                          index >= widget.labels.length - 2 &&
                          value.length < 4) {
                        return 'Use at least 4 characters.';
                      }
                      if (widget.newPassword &&
                          index == widget.labels.length - 1 &&
                          value != _controllers[index - 1].text) {
                        return 'The passwords do not match.';
                      }
                      return null;
                    },
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: !_obscure,
                onChanged: (value) =>
                    setState(() => _obscure = !(value ?? false)),
                title: const Text(
                  'Show passwords',
                  style: TextStyle(fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              _controllers.map((controller) => controller.text).toList(),
            );
          }
        },
        child: const Text('Continue'),
      ),
    ],
  );
}
