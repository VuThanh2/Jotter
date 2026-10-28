import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_note_repository.dart';
import '../data/account_api.dart';
import '../data/offline_note_repository.dart';
import '../data/sync_api.dart';
import '../data/note_repository.dart';
import '../data/preview_note_repository.dart';
import '../models/jotter_label.dart';
import '../models/jotter_note.dart';
import '../models/jotter_preferences.dart';
import '../theme.dart';
import '../widgets/account_dialog.dart';
import '../widgets/account_settings_dialog.dart';
import '../widgets/note_details_dialog.dart';
import '../widgets/ask_notes_dialog.dart';
import '../widgets/sync_status_dialog.dart';
import '../widgets/note_card.dart';
import '../widgets/note_editor.dart';

enum _Section { all, pinned, shared, label }

enum _Sort { updated, title }

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    this.repository,
    this.preferences = const JotterPreferences(),
    this.onPreferencesChanged,
  });
  final NoteRepository? repository;
  final JotterPreferences preferences;
  final ValueChanged<JotterPreferences>? onPreferencesChanged;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  late NoteRepository _repository;
  List<JotterNote> _notes = [];
  List<JotterLabel> _labels = [];
  _Section _section = _Section.all;
  _Sort _sort = _Sort.updated;
  String? _labelId;
  String? _error;
  bool _loading = true;
  bool _listMode = false;
  bool _opening = false;
  bool _editing = false;
  bool _searching = false;
  Timer? _searchTimer;
  int _searchGeneration = 0;
  List<JotterNote>? _searchResults;
  final Set<String> _busyIds = {};
  late JotterPreferences _preferences;
  Uint8List? _avatar;
  final Map<String, String> _sharedOwners = {};
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  final _editorUpdates = ValueNotifier<Map<String, dynamic>?>(null);
  Timer? _versionPoll;
  String? _editingNoteId;
  bool _checkingVersion = false;
  ApiNoteRepository? get _api => switch (_repository) {
    ApiNoteRepository value => value,
    OfflineNoteRepository value => value.remote,
    _ => null,
  };
  OfflineNoteRepository? get _offline => _repository is OfflineNoteRepository
      ? _repository as OfflineNoteRepository
      : null;

  void _syncChanged() {
    if (mounted) setState(() {});
  }

  void _bindSync() {
    _realtimeSubscription?.cancel();
    _offline?.syncStatus.addListener(_syncChanged);
    _realtimeSubscription = _offline?.realtimeEvents.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'workspaceSynced') {
        setState(() {
          _notes = List.of(_offline!.cachedNotes);
          _labels = List.of(_offline!.cachedLabels);
          final current = {for (final note in _notes) note.id: note};
          _searchResults = _searchResults
              ?.where((note) => current.containsKey(note.id))
              .map((note) => current[note.id]!)
              .toList();
        });
        if (_search.text.isNotEmpty && !_editing) _searchChanged();
      } else {
        if (event['type'] == 'accessRevoked') {
          final id = event['noteId'];
          setState(() {
            if (event['isProtected'] == true) {
              JotterNote redact(JotterNote note) => note.id == id
                  ? note.copyWith(
                      isProtected: true,
                      content: '',
                      preview: '',
                      contentLoaded: false,
                    )
                  : note;
              _notes = _notes.map(redact).toList();
              _searchResults = _searchResults?.map(redact).toList();
            } else {
              _notes.removeWhere((note) => note.id == id);
              _searchResults?.removeWhere((note) => note.id == id);
            }
          });
        }
        _editorUpdates.value = Map<String, dynamic>.from(event);
      }
    });
  }

  void _applyPreferences(JotterPreferences value) {
    setState(() {
      _preferences = value;
      _listMode = value.listViewMode == 'List';
    });
    widget.onPreferencesChanged?.call(value);
  }

  Future<void> _loadAccount() async {
    final api = _api;
    if (api == null) return;
    try {
      await api.getProfile();
      final preferences = await api.getPreferences();
      if (!mounted || !identical(api, _api)) return;
      _applyPreferences(preferences);
      Uint8List? avatar;
      try {
        avatar = await api.getAvatar();
      } catch (_) {
        /* Profile stays usable if an avatar is unavailable. */
      }
      final sharedOwners = <String, String>{};
      String? cursor;
      try {
        do {
          final page = await api.request(
            'GET',
            '/api/shared-with-me',
            query: {'limit': '100', 'cursor': ?cursor},
          );
          for (final item in page['items'] as List? ?? []) {
            final owner = item['sharedBy'] as Map?;
            if (owner != null) {
              sharedOwners[item['noteId'] as String] =
                  owner['displayName'] as String? ??
                  owner['email'] as String? ??
                  'Shared with you';
            }
          }
          cursor = page['nextCursor'] as String?;
        } while (cursor != null);
      } catch (_) {
        /* Notes can still be opened if share metadata is unavailable. */
      }
      if (!mounted || !identical(api, _api)) return;
      setState(() {
        _avatar = avatar;
        _sharedOwners.clear();
        _sharedOwners.addAll(sharedOwners);
      });
    } catch (error) {
      if (mounted && identical(api, _api)) {
        _notify(
          'Account settings could not be refreshed. Your current preferences are still available.',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PreviewNoteRepository();
    _preferences = widget.preferences;
    _listMode = _preferences.listViewMode == 'List';
    _bindSync();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _realtimeSubscription?.cancel();
    _offline?.syncStatus.removeListener(_syncChanged);
    _editorUpdates.dispose();
    _versionPoll?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    if (_offline != null) {
      _offline!.dispose();
    } else if (_api != null) {
      _api!.dispose();
    } else {
      _repository.close();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repository = _repository;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        repository.listNotes(),
        repository.listLabels(),
      ]);
      if (!mounted || !identical(repository, _repository)) return;
      setState(() {
        _notes = List.of(values[0] as List<JotterNote>);
        _labels = List.of(values[1] as List<JotterLabel>);
      });
    } catch (error) {
      if (mounted && identical(repository, _repository)) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && identical(repository, _repository)) {
        setState(() => _loading = false);
      }
    }
  }

  void _refresh() {
    if (_search.text.trim().isNotEmpty && !_repository.isPreview) {
      _searchChanged();
    } else {
      _load();
    }
  }

  void _resetSearch() {
    _searchTimer?.cancel();
    _searchGeneration++;
    _search.clear();
    _searchResults = null;
    _searching = false;
  }

  void _searchChanged() {
    _searchTimer?.cancel();
    final generation = ++_searchGeneration;
    final query = _search.text.trim();
    final repository = _repository;
    setState(() {
      _searchResults = null;
      _searching = query.isNotEmpty && !repository.isPreview;
      _error = null;
    });
    if (!_searching) return;
    _searchTimer = Timer(Duration(milliseconds: 300), () async {
      try {
        final result = await repository.listNotes(query: query);
        if (!mounted ||
            generation != _searchGeneration ||
            !identical(repository, _repository)) {
          return;
        }
        setState(() => _searchResults = result);
      } catch (error) {
        if (mounted && generation == _searchGeneration) {
          setState(() => _error = _message(error));
        }
      } finally {
        if (mounted && generation == _searchGeneration) {
          setState(() => _searching = false);
        }
      }
    });
  }

  String get _title => switch (_section) {
    _Section.all => 'All notes',
    _Section.pinned => 'Pinned notes',
    _Section.shared => 'Shared with me',
    _Section.label =>
      _labels.where((label) => label.id == _labelId).firstOrNull?.name ??
          'Label',
  };

  List<JotterNote> get _visibleNotes {
    final query = _search.text.trim().toLowerCase();
    final source = query.isNotEmpty && !_repository.isPreview
        ? _searchResults ?? <JotterNote>[]
        : _notes;
    final notes = source.where((note) {
      final inSection = switch (_section) {
        _Section.all => true,
        _Section.pinned => note.isPinned,
        _Section.shared => !note.isOwned,
        _Section.label => note.labelIds.contains(_labelId),
      };
      final text =
          '${note.title} ${note.isProtected
                  ? ''
                  : note.contentLoaded
                  ? note.content
                  : note.preview}'
              .toLowerCase();
      return inSection &&
          (!_repository.isPreview || query.isEmpty || text.contains(query));
    }).toList();
    notes.sort(
      (a, b) => _sort == _Sort.title
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : b.updatedAt.compareTo(a.updatedAt),
    );
    return notes;
  }

  void _navigate(_Section section, [String? labelId]) {
    setState(() {
      _section = section;
      _labelId = labelId;
      _resetSearch();
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _replace(JotterNote note) {
    if (!mounted) return;
    setState(() {
      final index = _notes.indexWhere((item) => item.id == note.id);
      if (index < 0) {
        _notes.add(note);
      } else {
        _notes[index] = note;
      }
      _searchResults = _searchResults
          ?.map((item) => item.id == note.id ? note : item)
          .toList();
    });
  }

  String _message(Object error) => error is RepositoryException
      ? error.message
      : 'Something went wrong. Please try again.';

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _newNote() async {
    if (_opening || _editing || _loading) return;
    final now = DateTime.now();
    final note = JotterNote(
      id: generateUuid(),
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
      labelIds: _section == _Section.label && _labelId != null
          ? [_labelId!]
          : [],
    );
    await _edit(note, isNew: true);
  }

  Future<void> _openNote(JotterNote note) async {
    if (_opening || _editing) return;
    setState(() => _opening = true);
    try {
      JotterNote loaded;
      try {
        loaded = await _repository.getNote(note.id);
      } on RepositoryException catch (error) {
        if (error.code != 'NoteLocked' && error.statusCode != 423) rethrow;
        if (!mounted) return;
        final password = await _askText(
          title: 'A little privacy',
          description:
              'Enter this note’s password to open it.${_repository.isPreview ? '\nPreview password: 1234' : ''}',
          fieldLabel: 'Note password',
          action: 'Unlock note',
          obscure: true,
        );
        if (password == null) return;
        loaded = await _repository.unlockNote(note.id, password);
      }
      if (!mounted) return;
      setState(() => _opening = false);
      await _edit(loaded);
    } catch (error) {
      _notify(_message(error));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _edit(JotterNote note, {bool isNew = false}) async {
    if (!mounted) return;
    setState(() => _editing = true);
    var creating = isNew;
    String? copyId;
    _editorUpdates.value = null;
    await _offline?.watchNote(isNew ? null : note.id);
    if (!mounted) return;
    _editingNoteId = isNew ? null : note.id;
    final api = _api;
    if (!isNew && api != null) {
      _versionPoll = Timer.periodic(const Duration(seconds: 25), (_) async {
        if (_checkingVersion ||
            !mounted ||
            _editingNoteId != note.id ||
            !identical(api, _api) ||
            (_offline?.syncStatus.value.realtimeConnected ?? false) ||
            (_offline?.syncStatus.value.isOffline ?? false)) {
          return;
        }
        _checkingVersion = true;
        try {
          final version = await api.getNoteVersion(note.id);
          if (mounted && _editingNoteId == note.id && version > note.version) {
            _editorUpdates.value = {
              'type': 'noteChanged',
              'noteId': note.id,
              'version': version,
            };
          }
        } catch (error) {
          if (mounted &&
              _editingNoteId == note.id &&
              error is RepositoryException &&
              [403, 404, 423].contains(error.statusCode)) {
            _editorUpdates.value = {
              'type': 'accessRevoked',
              'noteId': note.id,
              'isProtected': error.statusCode == 423 || note.isProtected,
            };
          }
        } finally {
          _checkingVersion = false;
        }
      });
    }
    final saved = await showNoteEditor(
      context,
      note: note,
      labels: _labels,
      noteFontSize: _preferences.noteFontSize.toDouble(),
      updates: _editorUpdates,
      onCompare: isNew ? null : _compareVersion,
      onSaveCopy: note.isProtected
          ? null
          : (draft) async {
              final now = DateTime.now();
              final title = draft.title.isEmpty ? 'Untitled note' : draft.title;
              final copy = draft.copyWith(
                id: copyId ??= generateUuid(),
                title:
                    '${title.length > 193 ? title.substring(0, 193) : title} (copy)',
                createdAt: now,
                updatedAt: now,
                version: 0,
                isOwned: true,
                isShared: false,
                isPinned: false,
                isProtected: false,
                canEdit: true,
                labelIds: [],
                conflictOfNoteId: isNew ? null : note.id,
              );
              final result = await _repository.saveNote(copy, isNew: true);
              final pendingOriginal = _offline?.pendingChanges
                  .where(
                    (change) => change.noteId == note.id && change.isBlocked,
                  )
                  .firstOrNull;
              if (pendingOriginal != null) {
                await _offline!.discardPending(pendingOriginal.id);
              }
              _replace(result);
              return result;
            },
      onSave: (draft) async {
        var result = await _repository.saveNote(draft, isNew: creating);
        creating = false;
        _replace(result);
        if (isNew && draft.labelIds.isNotEmpty) {
          try {
            result = await _repository.setLabels(result, draft.labelIds);
          } catch (_) {
            result = result.copyWith(labelIds: []);
            _notify(
              'Your note was saved, but its label could not be added. Try Edit labels from the note menu.',
            );
          }
          _replace(result);
        }
        return result;
      },
    );
    _versionPoll?.cancel();
    _editingNoteId = null;
    await _offline?.watchNote(null);
    if (mounted) setState(() => _editing = false);
    if (saved != null && mounted) {
      if (_search.text.trim().isNotEmpty && !_repository.isPreview) {
        _searchChanged();
      }
      _notify(
        _repository.isPreview
            ? 'Note saved in this preview session.'
            : (_offline?.syncStatus.value.pendingCount ?? 0) > 0
            ? 'Note saved on this device. It will sync when connected.'
            : 'Note saved.',
      );
    }
  }

  Future<void> _action(JotterNote note, NoteAction action) async {
    if (_busyIds.contains(note.id)) return;
    if ([
      NoteAction.files,
      NoteAction.sharing,
      NoteAction.protection,
      NoteAction.summary,
    ].contains(action)) {
      await _noteTools(note, switch (action) {
        NoteAction.files => 'Files',
        NoteAction.sharing => 'Sharing',
        NoteAction.protection => 'Protection',
        _ => 'Summary',
      });
      return;
    }
    if (action == NoteAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete this note?'),
          content: Text(
            '“${note.title.isEmpty ? 'Untitled note' : note.title}” will be permanently deleted. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Keep note'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete note'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (action == NoteAction.labels) {
      await _editLabels(note);
      return;
    }
    setState(() => _busyIds.add(note.id));
    try {
      if (action == NoteAction.pin) {
        _replace(await _repository.pinNote(note, !note.isPinned));
      } else {
        await _repository.deleteNote(note.id);
        if (mounted) {
          setState(() {
            _notes.removeWhere((item) => item.id == note.id);
            _searchResults?.removeWhere((item) => item.id == note.id);
          });
        }
        _notify('Note deleted.');
      }
    } catch (error) {
      _notify(_message(error));
    } finally {
      if (mounted) setState(() => _busyIds.remove(note.id));
    }
  }

  Future<void> _noteTools(JotterNote note, String tab) async {
    final api = _api;
    if (api == null) {
      _notify(
        'Sign in to use files, sharing, protection, and AI with your saved notes.',
      );
      return;
    }
    if (_editing || _opening) return;
    _editorUpdates.value = null;
    await _offline?.watchNote(note.id);
    if (!mounted) return;
    final changed = await showNoteDetailsDialog(
      context,
      repository: api,
      note: note,
      initialTab: tab,
      updates: _editorUpdates,
    );
    await _offline?.watchNote(null);
    if (changed == true && mounted) {
      await _offline?.synchronize();
      await _load();
    }
  }

  Future<void> _askNotes() async {
    final api = _api;
    if (api == null) {
      _notify('Sign in to ask questions about your saved notes.');
      return;
    }
    String? selected;
    await showAskNotesDialog(
      context,
      repository: api,
      onOpenNote: (id) async {
        selected = id;
      },
    );
    if (selected != null && mounted) {
      try {
        await _openNote(await _repository.getNote(selected!));
      } catch (error) {
        _notify(_message(error));
      }
    }
  }

  Future<void> _compareVersion(JotterNote draft) async {
    try {
      final saved = await (_api ?? _repository).getNote(draft.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 900,
            height: 650,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(22, 14, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Compare versions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close comparison',
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    tabs: [
                      Tab(text: 'Your draft · v${draft.version}'),
                      Tab(text: 'Saved · v${saved.version}'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [draft, saved]
                          .map(
                            (note) => SingleChildScrollView(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    note.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  SizedBox(height: 18),
                                  SelectableText(
                                    note.content,
                                    style: TextStyle(
                                      fontSize: _preferences.noteFontSize
                                          .toDouble(),
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Your draft stays open. Save a copy to keep it alongside the server version.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      _notify(_message(error));
    }
  }

  Future<void> _manageLabels() async {
    if (_labels.isEmpty) {
      await _addLabel();
      return;
    }
    final selected = await showDialog<(JotterLabel, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage labels'),
        content: SizedBox(
          width: 390,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _labels
                  .map(
                    (label) => ListTile(
                      title: Text(label.name),
                      contentPadding: EdgeInsets.zero,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rename ${label.name}',
                            onPressed: () =>
                                Navigator.pop(context, (label, 'rename')),
                            icon: Icon(Icons.edit_outlined, size: 19),
                          ),
                          IconButton(
                            tooltip: 'Delete ${label.name}',
                            onPressed: () =>
                                Navigator.pop(context, (label, 'delete')),
                            icon: Icon(Icons.delete_outline, size: 19),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final (label, action) = selected;
    try {
      if (action == 'rename') {
        final name = await _askText(
          title: 'Rename ${label.name}',
          description: 'Notes keep their label when its name changes.',
          fieldLabel: 'Label name',
          action: 'Rename label',
          maxLength: 50,
        );
        if (name == null) return;
        final updated = await _repository.renameLabel(label.id, name);
        if (mounted) {
          setState(
            () => _labels = _labels
                .map((item) => item.id == label.id ? updated : item)
                .toList(),
          );
        }
      } else {
        final count = _notes
            .where((note) => note.labelIds.contains(label.id))
            .length;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete ${label.name}?'),
            content: Text(
              'This removes the label from $count note${count == 1 ? '' : 's'}. The notes are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete label'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await _repository.deleteLabel(label.id);
        if (!mounted) return;
        setState(() {
          _labels.removeWhere((item) => item.id == label.id);
          _notes = _notes
              .map(
                (note) => note.copyWith(
                  labelIds: note.labelIds
                      .where((id) => id != label.id)
                      .toList(),
                ),
              )
              .toList();
        });
        if (_labelId == label.id) _navigate(_Section.all);
      }
    } catch (error) {
      _notify(_message(error));
    }
  }

  Future<void> _setListMode(bool list) async {
    final updated = _preferences.copyWith(listViewMode: list ? 'List' : 'Grid');
    _applyPreferences(updated);
    try {
      if (_api != null) await _api!.updatePreferences(updated);
    } catch (error) {
      _notify(
        'View changed for this session. Its account preference could not be saved.',
      );
    }
  }

  Future<void> _editLabels(JotterNote note) async {
    if (_labels.isEmpty) {
      _notify('Create a label from the sidebar first.');
      return;
    }
    final selected = note.labelIds.toSet();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('A place for this thought'),
          content: SizedBox(
            width: 350,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _labels
                    .map(
                      (label) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(label.name),
                        value: selected.contains(label.id),
                        onChanged: (value) => update(() {
                          value == true
                              ? selected.add(label.id)
                              : selected.remove(label.id);
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected.toList()),
              child: Text('Save labels'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busyIds.add(note.id));
    try {
      _replace(await _repository.setLabels(note, result));
    } catch (error) {
      _notify(_message(error));
    } finally {
      if (mounted) setState(() => _busyIds.remove(note.id));
    }
  }

  Future<void> _addLabel() async {
    final repository = _repository;
    final name = await _askText(
      title: 'Give your thoughts a home',
      description: 'Labels keep related notes together.',
      fieldLabel: 'Label name',
      action: 'Create label',
      maxLength: 50,
    );
    if (name == null) return;
    try {
      final label = await repository.createLabel(name);
      if (!mounted || !identical(repository, _repository)) return;
      setState(() => _labels.add(label));
      _navigate(_Section.label, label.id);
      _notify('Label created. Add it to a note from its actions menu.');
    } catch (error) {
      _notify(_message(error));
    }
  }

  Future<String?> _askText({
    required String title,
    required String description,
    required String fieldLabel,
    required String action,
    bool obscure = false,
    int? maxLength,
  }) async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(color: context.jotterColors.muted),
                ),
                SizedBox(height: 22),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  obscureText: obscure,
                  maxLength: maxLength,
                  decoration: InputDecoration(labelText: fieldLabel),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter ${fieldLabel.toLowerCase()}.'
                      : null,
                  onFieldSubmitted: (_) {
                    if (form.currentState!.validate()) {
                      Navigator.pop(
                        context,
                        obscure ? controller.text : controller.text.trim(),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  obscure ? controller.text : controller.text.trim(),
                );
              }
            },
            child: Text(action),
          ),
        ],
      ),
    );
    // Let the dialog finish its reverse animation before disposing its input.
    await Future<void>.delayed(Duration(milliseconds: 250));
    controller.dispose();
    return value;
  }

  Future<void> _connect() async {
    if (_busyIds.isNotEmpty || _opening || _editing || _loading) return;
    final repository = await showAccountDialog(context);
    if (repository == null) return;
    if (!mounted) {
      await repository.close();
      return;
    }
    await _repository.close();
    if (!mounted) {
      await repository.close();
      return;
    }
    final offline = await OfflineNoteRepository.open(repository);
    if (!mounted) {
      await offline.dispose();
      return;
    }
    setState(() {
      _repository = offline;
      _notes = [];
      _labels = [];
      _section = _Section.all;
      _labelId = null;
      _resetSearch();
    });
    _bindSync();
    await _load();
    await _loadAccount();
  }

  Future<void> _account() async {
    if (_busyIds.isNotEmpty || _opening || _editing || _loading) return;
    if (_repository.isPreview) {
      await _connect();
      return;
    }
    final repository = _api;
    if (repository == null) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(repository.account.displayName),
        content: Text(
          'Signed in as ${repository.account.email}.\n\nYour saved notes stay in your account when you sign out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'signout'),
            child: Text('Sign out'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'settings'),
            child: Text('Account settings'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'settings') {
      await showAccountSettingsDialog(
        context,
        repository: repository,
        preferences: _preferences,
        onPreferencesChanged: _applyPreferences,
      );
      await _loadAccount();
      return;
    }
    if (choice != 'signout') return;
    if ((_offline?.syncStatus.value.pendingCount ?? 0) > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Sign out with pending changes?'),
          content: Text(
            'Unsynced changes on this device will be discarded. Open sync status to review or export them before signing out.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Stay signed in'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Discard and sign out'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _offline?.syncStatus.removeListener(_syncChanged);
    await _realtimeSubscription?.cancel();
    await _repository.close();
    if (!mounted) return;
    setState(() {
      _repository = PreviewNoteRepository();
      _avatar = null;
      _notes = [];
      _labels = [];
      _section = _Section.all;
      _labelId = null;
      _resetSearch();
    });
    _applyPreferences(const JotterPreferences());
    await _load();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      SingleActivator(LogicalKeyboardKey.keyN, control: true): _newNote,
      SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newNote,
      SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
          _searchFocus.requestFocus(),
      SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
          _searchFocus.requestFocus(),
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1000;
        return Scaffold(
          key: _scaffoldKey,
          drawer: desktop
              ? null
              : Drawer(
                  width: 264,
                  backgroundColor: context.jotterColors.sidebar,
                  child: SafeArea(child: _sidebar()),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop) SizedBox(width: 232, child: _sidebar()),
                Expanded(
                  child: Column(
                    children: [
                      _topBar(desktop),
                      if (_opening) LinearProgressIndicator(minHeight: 2),
                      Expanded(child: _content()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _sidebar() {
    final account = _api?.account;
    final name = account?.displayName ?? 'Your workspace';
    return Container(
      decoration: BoxDecoration(
        color: context.jotterColors.sidebar,
        border: Border(right: BorderSide(color: context.jotterColors.line)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(25, 30, 22, 30),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: -.1,
                    child: Container(
                      width: 34,
                      height: 38,
                      decoration: BoxDecoration(
                        color: JotterColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                  ),
                  SizedBox(width: 11),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: 'jotter',
                          children: [
                            TextSpan(
                              text: '.',
                              style: TextStyle(color: JotterColors.accent),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: FilledButton.icon(
                onPressed: _loading ? null : _newNote,
                icon: Icon(Icons.add_rounded, size: 20),
                label: Text('New note'),
              ),
            ),
            SizedBox(height: 30),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 14),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 0, 12),
                    child: Text(
                      'WORKSPACE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                        color: context.jotterColors.muted,
                      ),
                    ),
                  ),
                  _navItem(
                    Icons.notes_rounded,
                    'All notes',
                    _notes.length,
                    _section == _Section.all,
                    () => _navigate(_Section.all),
                  ),
                  _navItem(
                    Icons.push_pin_outlined,
                    'Pinned notes',
                    _notes.where((note) => note.isPinned).length,
                    _section == _Section.pinned,
                    () => _navigate(_Section.pinned),
                  ),
                  _navItem(
                    Icons.people_outline_rounded,
                    'Shared with me',
                    _notes.where((note) => !note.isOwned).length,
                    _section == _Section.shared,
                    () => _navigate(_Section.shared),
                  ),
                  _navItem(
                    Icons.auto_awesome_outlined,
                    'Ask your notes',
                    -1,
                    false,
                    _askNotes,
                  ),
                  SizedBox(height: 28),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 3, 9),
                    child: Row(
                      children: [
                        Text(
                          'YOUR LABELS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                            color: context.jotterColors.muted,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          tooltip: 'Create label',
                          onPressed: _loading ? null : _addLabel,
                          icon: Icon(Icons.add_rounded, size: 17),
                          constraints: BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  for (var index = 0; index < _labels.length; index++)
                    _labelItem(_labels[index], index),
                  TextButton.icon(
                    onPressed: _loading ? null : _manageLabels,
                    icon: Icon(Icons.tune_rounded, size: 16),
                    label: Text('Manage labels'),
                  ),
                  if (_labels.isEmpty && !_loading)
                    Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'A label for every kind of thought.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.jotterColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_repository.isPreview)
              Padding(
                padding: EdgeInsets.fromLTRB(22, 12, 22, 22),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.jotterColors.tint(const Color(0xFFE8E9E0)),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 23,
                        color: Color(0xFF7C856B),
                      ),
                      SizedBox(height: 11),
                      Text(
                        'Room for a thought.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'A small idea today.\nSomething wonderful tomorrow.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.7,
                          color: context.jotterColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_offline != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: TextButton.icon(
                  onPressed: () => showSyncStatusDialog(context, _offline!),
                  icon: Icon(
                    _offline!.syncStatus.value.isOffline
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                    size: 17,
                  ),
                  label: Text(
                    _offline!.syncStatus.value.label,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: _account,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: JotterColors.peach,
                  backgroundImage: _avatar == null
                      ? null
                      : MemoryImage(_avatar!),
                  child: _avatar != null
                      ? null
                      : Text(
                          name.characters.first.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: JotterColors.accent,
                          ),
                        ),
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _repository.isPreview
                      ? 'Preview · Sign in to sync'
                      : 'Connected to Jotter',
                  style: TextStyle(
                    fontSize: 10,
                    color: context.jotterColors.muted,
                  ),
                ),
                trailing: Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: context.jotterColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String title,
    int count,
    bool selected,
    VoidCallback onTap,
  ) => Padding(
    padding: EdgeInsets.only(bottom: 5),
    child: Material(
      color: selected
          ? context.jotterColors.tint(const Color(0xFFE7E5DC))
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? JotterColors.accent
                    : context.jotterColors.muted,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (count >= 0)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.jotterColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _labelItem(JotterLabel label, int index) {
    final selected = _section == _Section.label && _labelId == label.id;
    const colors = [
      Color(0xFFBD9D62),
      Color(0xFF849578),
      Color(0xFFBD8C7D),
      Color(0xFF9D8AB4),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? context.jotterColors.tint(const Color(0xFFE7E5DC))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _navigate(_Section.label, label.id),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 17, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 17),
                Expanded(
                  child: Text(
                    label.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  '${_notes.where((note) => note.labelIds.contains(label.id)).length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.jotterColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(bool desktop) => Container(
    height: 73,
    padding: EdgeInsets.symmetric(horizontal: desktop ? 40 : 16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.jotterColors.line)),
    ),
    child: Row(
      children: [
        if (!desktop)
          Padding(
            padding: EdgeInsets.only(right: 9),
            child: IconButton(
              tooltip: 'Open navigation',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: Icon(Icons.menu_rounded, size: 22),
            ),
          ),
        Icon(Icons.home_outlined, size: 16, color: context.jotterColors.muted),
        SizedBox(width: 10),
        if (MediaQuery.sizeOf(context).width > 600) ...[
          Text(
            'Workspace',
            style: TextStyle(fontSize: 12, color: context.jotterColors.muted),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '/',
              style: TextStyle(color: context.jotterColors.line),
            ),
          ),
        ],
        Expanded(
          child: Text(
            _title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Refresh notes',
          onPressed: _loading ? null : _refresh,
          icon: Icon(
            Icons.refresh_rounded,
            size: 19,
            color: context.jotterColors.muted,
          ),
        ),
        SizedBox(width: 8),
        if (_repository.isPreview)
          TextButton.icon(
            onPressed: _connect,
            icon: Icon(Icons.login_rounded, size: 16),
            label: Text('Sign in'),
          )
        else
          IconButton(
            tooltip: 'Your account',
            onPressed: _account,
            icon: Icon(Icons.account_circle_outlined, size: 23),
          ),
      ],
    ),
  );

  Widget _content() => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 650;
      final horizontal = narrow ? 20.0 : 40.0;
      final available = constraints.maxWidth - horizontal * 2;
      final columns = available >= 1000
          ? 3
          : available >= 600
          ? 2
          : 1;
      final visible = _visibleNotes;
      final pinned = visible.where((note) => note.isPinned).toList();
      final other = visible.where((note) => !note.isPinned).toList();
      final group =
          _section != _Section.pinned &&
          _search.text.isEmpty &&
          pinned.isNotEmpty;
      return Scrollbar(
        controller: _scroll,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 38, horizontal, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A SPACE FOR YOUR THOUGHTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.jotterColors.muted,
                        letterSpacing: 1.8,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.jotterColors.sidebar,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      '${visible.length}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.jotterColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 9),
                              Text(
                                switch (_section) {
                                  _Section.all => 'A little less to remember. A little more room to think.',
                                  _Section.pinned =>
                                    'Keep the important things close.',
                                  _Section.shared =>
                                    'Good ideas are even better together.',
                                  _Section.label => 'Related thoughts, right where they belong.',
                                },
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.jotterColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!narrow)
                          Padding(
                            padding: EdgeInsets.only(left: 20, top: 4),
                            child: FilledButton.icon(
                              onPressed: _loading ? null : _newNote,
                              icon: Icon(Icons.add_rounded, size: 18),
                              label: Text('New note'),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 28),
                    _toolbar(narrow),
                    if (_api != null && !_api!.account.isActivated)
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          children: [
                            Text(
                              'Verify your email to enable all account features.',
                            ),
                            TextButton(
                              onPressed: () async {
                                await showActivationDialog(
                                  context,
                                  repository: _api!,
                                );
                                if (mounted) {
                                  setState(() {});
                                  await _offline?.synchronize();
                                }
                              },
                              child: Text('Verify email'),
                            ),
                          ],
                        ),
                      ),
                    if (_repository.isPreview)
                      Padding(
                        padding: EdgeInsets.only(top: 19),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: context.jotterColors.muted,
                              ),
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'You’re in a preview workspace. Changes last for this session. Sign in to save to your account.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.6,
                                  color: context.jotterColors.muted.withValues(
                                    alpha: .9,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: EdgeInsets.only(top: 22),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.jotterColors.tint(
                              JotterColors.peach,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: _refresh,
                                child: Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: 29),
                  ],
                ),
              ),
            ),
            if (_loading || _searching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(80),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _emptyState())
            else ...[
              if (group) ...[
                _sectionHeading(
                  'PINNED',
                  Icons.push_pin_outlined,
                  horizontal,
                  pinned.length,
                ),
                _noteSliver(pinned, columns, horizontal),
                if (other.isNotEmpty)
                  _sectionHeading(
                    'EVERYTHING ELSE',
                    Icons.notes_rounded,
                    horizontal,
                    other.length,
                  ),
                if (other.isNotEmpty) _noteSliver(other, columns, horizontal),
              ] else ...[
                _sectionHeading(
                  _search.text.isNotEmpty ? 'SEARCH RESULTS' : 'YOUR NOTES',
                  Icons.notes_rounded,
                  horizontal,
                  visible.length,
                ),
                _noteSliver(visible, columns, horizontal),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Center(
                    child: Text(
                      'A home for your thoughts, big and small.',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.jotterColors.muted.withValues(alpha: .7),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _toolbar(bool narrow) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final search = TextField(
      controller: _search,
      focusNode: _searchFocus,
      onChanged: (_) => _searchChanged(),
      decoration: InputDecoration(
        hintText: 'Search your notes…',
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: context.jotterColors.muted,
        ),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: Icon(Icons.close_rounded, size: 17),
                onPressed: () => setState(_resetSearch),
              ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<_Sort>(
          tooltip: 'Sort notes',
          initialValue: _sort,
          onSelected: (value) => setState(() => _sort = value),
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: _Sort.updated,
              checked: _sort == _Sort.updated,
              child: Text('Last edited'),
            ),
            CheckedPopupMenuItem(
              value: _Sort.title,
              checked: _sort == _Sort.title,
              child: Text('Title A–Z'),
            ),
          ],
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_vert_rounded,
                  size: 17,
                  color: context.jotterColors.muted,
                ),
                if (!compact) ...[
                  SizedBox(width: 6),
                  Text(
                    _sort == _Sort.updated ? 'Last edited' : 'Title A–Z',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.jotterColors.muted,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 15,
                    color: context.jotterColors.muted,
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(width: 12),
        Container(
          padding: EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: context.jotterColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _viewButton(false, Icons.grid_view_rounded, 'Grid view'),
              _viewButton(true, Icons.view_agenda_outlined, 'List view'),
            ],
          ),
        ),
      ],
    );
    if (narrow) {
      return Column(
        children: [
          search,
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 10,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _newNote,
                  icon: Icon(Icons.add_rounded, size: 17),
                  label: Text('New note'),
                ),
                controls,
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: search,
          ),
        ),
        SizedBox(width: 20),
        controls,
      ],
    );
  }

  Widget _viewButton(bool listMode, IconData icon, String tooltip) => Tooltip(
    message: tooltip,
    child: Material(
      color: _listMode == listMode
          ? context.jotterColors.sidebar
          : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => _setListMode(listMode),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 17,
            color: _listMode == listMode
                ? context.jotterColors.ink
                : context.jotterColors.muted,
          ),
        ),
      ),
    ),
  );

  Widget _sectionHeading(
    String title,
    IconData icon,
    double horizontal,
    int count,
  ) => SliverPadding(
    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 14),
    sliver: SliverToBoxAdapter(
      child: Row(
        children: [
          Icon(icon, size: 13, color: context.jotterColors.muted),
          SizedBox(width: 7),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w600,
              color: context.jotterColors.muted,
            ),
          ),
          SizedBox(width: 7),
          Text(
            '($count)',
            style: TextStyle(fontSize: 10, color: context.jotterColors.muted),
          ),
        ],
      ),
    ),
  );

  Widget _noteSliver(List<JotterNote> notes, int columns, double horizontal) {
    Widget card(int index) {
      final note = notes[index];
      return AbsorbPointer(
        absorbing: _busyIds.contains(note.id),
        child: Opacity(
          opacity: _busyIds.contains(note.id) ? .55 : 1,
          child: NoteCard(
            key: ValueKey(note.id),
            note: note,
            labels: _labels,
            listMode: _listMode,
            sharedBy: _sharedOwners[note.id],
            defaultColor:
                _preferences.defaultNoteColor.toUpperCase() == '#FFFFFF' ||
                    !RegExp(r'^#[0-9a-fA-F]{6}$')
                        .hasMatch(_preferences.defaultNoteColor)
                ? null
                : Color(
                    int.parse(
                      'FF${_preferences.defaultNoteColor.substring(1)}',
                      radix: 16,
                    ),
                  ),
            onOpen: () => _openNote(note),
            onAction: (action) => _action(note, action),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 28),
      sliver: _listMode
          ? SliverList.separated(
              itemCount: notes.length,
              itemBuilder: (_, index) => card(index),
              separatorBuilder: (_, _) => SizedBox(height: 10),
            )
          : SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, index) => card(index),
                childCount: notes.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 290,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
              ),
            ),
    );
  }

  Widget _emptyState() {
    final searching = _search.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(25, 30, 25, 70),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 88,
            decoration: BoxDecoration(
              color: JotterColors.butter,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.edit_note_rounded,
              size: 42,
              color: Color(0xFFAA9566),
            ),
          ),
          SizedBox(height: 24),
          Text(
            searching
                ? 'No thoughts found. Yet.'
                : _section == _Section.pinned
                ? 'Keep a thought close.'
                : _section == _Section.shared
                ? 'A space for shared ideas.'
                : 'Good things start with a note.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 9),
          Text(
            searching
                ? 'Try a different word or clear your search.'
                : _section == _Section.pinned
                ? 'Pin a note from its actions menu to find it here.'
                : _section == _Section.shared
                ? 'Notes shared with your account will appear here.'
                : 'Capture an idea, make a list, or just start writing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.jotterColors.muted),
          ),
          SizedBox(height: 22),
          if (searching)
            OutlinedButton(
              onPressed: () => setState(_resetSearch),
              child: Text('Clear search'),
            )
          else if (_section != _Section.pinned && _section != _Section.shared)
            FilledButton.icon(
              onPressed: _newNote,
              icon: Icon(Icons.add_rounded, size: 18),
              label: Text('Write your first note'),
            ),
        ],
      ),
    );
  }
}
