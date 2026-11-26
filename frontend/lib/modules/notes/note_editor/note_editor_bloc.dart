import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/notes/note_editor/note_editor_event.dart';
import 'package:jotter/modules/notes/note_editor/note_editor_state.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/shared/lib/config.dart';
import 'package:jotter/shared/lib/debouncer.dart';

/// A Bloc rather than a Cubit: typing, autosave and realtime events interleave.
class NoteEditorBloc extends Bloc<NoteEditorEvent, NoteEditorState> {
  NoteEditorBloc(
    this._store, {
    required this.noteId,
    this.isNew = false,
    this.initialLabelIds = const [],
    Duration autosaveDelay = AppConfig.autosaveDelay,
  }) : _autosave = Debouncer(autosaveDelay),
       super(const NoteEditorState()) {
    on<EditorStarted>(_start);
    on<EditorTitleChanged>((event, emit) => _edit(emit, title: event.title));
    on<EditorContentChanged>(
      (event, emit) => _edit(emit, content: event.content),
    );
    on<EditorAutosaveDue>((_, emit) => _save(emit));
    on<EditorFlushRequested>((_, emit) {
      _autosave.cancel();
      return _save(emit);
    });
    on<EditorUnlockRequested>(_unlock);
    on<EditorReloadRequested>((_, emit) => _load(emit, replaceDraft: true));
    on<EditorKeepMineRequested>(_keepMine);
    on<EditorPinToggled>(_togglePin);
    on<EditorLabelsChanged>(_setLabels);
    on<EditorDeleteRequested>(_delete);
    on<EditorRemoteEvent>(_remote);
  }

  static const _unavailable =
      'This note no longer exists, or you no longer have access to it.';

  final NoteStore _store;
  final String noteId;
  final bool isNew;
  final List<String> initialLabelIds;
  final Debouncer _autosave;
  StreamSubscription<Map<String, dynamic>>? _events;
  bool _saving = false;
  bool _saveAgain = false;
  int? _remoteVersionDuringSave;

  Future<void> _start(
    EditorStarted event,
    Emitter<NoteEditorState> emit,
  ) async {
    final cached = _store.cached(noteId);
    if (isNew && cached == null) {
      final now = DateTime.now();
      emit(
        NoteEditorState(
          status: EditorStatus.ready,
          isNew: true,
          note: JotterNote(
            id: noteId,
            title: '',
            content: '',
            createdAt: now,
            updatedAt: now,
            labelIds: initialLabelIds,
          ),
        ),
      );
      return;
    }
    if (cached != null && cached.contentLoaded && !cached.isProtected) {
      emit(_withNote(state, cached).copyWith(status: EditorStatus.ready));
    }
    _events = _store.noteEvents
        .where((event) => event['noteId'] == noteId)
        .listen((event) => add(EditorRemoteEvent(event)));
    unawaited(_store.watch(noteId));
    await _load(emit, replaceDraft: false);
  }

  Future<void> _load(
    Emitter<NoteEditorState> emit, {
    required bool replaceDraft,
  }) async {
    try {
      final note = await _store.open(noteId);
      if (replaceDraft || !state.isDirty || state.note == null) {
        emit(
          _withNote(state, note).copyWith(
            status: EditorStatus.ready,
            newerVersionAvailable: false,
            saveStatus: SaveStatus.idle,
          ),
        );
      } else if (note.version > state.note!.version) {
        emit(state.copyWith(newerVersionAvailable: true));
      }
    } on RepositoryException catch (error) {
      _handleFailure(emit, error, whileLoading: true);
    }
  }

  void _edit(Emitter<NoteEditorState> emit, {String? title, String? content}) {
    if (!state.canEdit) return;
    emit(
      state.copyWith(
        title: title,
        content: content,
        saveStatus: SaveStatus.pending,
      ),
    );
    _autosave.run(() => add(const EditorAutosaveDue()));
  }

  Future<void> _save(Emitter<NoteEditorState> emit) async {
    if (_saving) {
      _saveAgain = true;
      return;
    }
    _saving = true;
    try {
      do {
        _saveAgain = false;
        await _saveOnce(emit);
      } while (_saveAgain && !emit.isDone);
    } finally {
      _saving = false;
    }
  }

  Future<void> _saveOnce(Emitter<NoteEditorState> emit) async {
    final draftState = state;
    final base = draftState.note;
    if (base == null || !draftState.canEdit) return;
    if (!draftState.isDirty && !draftState.isNew) {
      if (draftState.saveStatus == SaveStatus.pending) {
        emit(draftState.copyWith(saveStatus: SaveStatus.saved));
      }
      return;
    }
    if (!draftState.hasText) {
      // An empty new note is simply never created.
      emit(
        draftState.isNew
            ? draftState.copyWith(saveStatus: SaveStatus.idle)
            : draftState.copyWith(
                saveStatus: SaveStatus.failed,
                saveError:
                    'Add a title or some text. Empty notes are not saved.',
              ),
      );
      return;
    }
    emit(draftState.copyWith(saveStatus: SaveStatus.saving));
    try {
      var saved = await _store.save(
        base.copyWith(title: draftState.title, content: draftState.content),
        isNew: draftState.isNew,
      );
      if (draftState.isNew && initialLabelIds.isNotEmpty) {
        saved = await _store.setLabels(saved, initialLabelIds);
      }
      final current = state;
      final stillDirty =
          current.title != saved.title || current.content != saved.content;
      final sync = _store.syncStatus.value;
      emit(
        current.copyWith(
          note: saved,
          isNew: false,
          saveStatus: stillDirty
              ? SaveStatus.pending
              : sync.isOffline || sync.pendingCount > 0
              ? SaveStatus.savedOffline
              : SaveStatus.saved,
        ),
      );
      if (stillDirty) _saveAgain = true;
      final remoteVersion = _remoteVersionDuringSave;
      _remoteVersionDuringSave = null;
      if (remoteVersion != null && remoteVersion > saved.version) {
        emit(state.copyWith(newerVersionAvailable: true));
      }
    } on RepositoryException catch (error) {
      _handleFailure(emit, error, whileLoading: false);
    }
  }

  void _handleFailure(
    Emitter<NoteEditorState> emit,
    RepositoryException error, {
    required bool whileLoading,
  }) {
    if (error.statusCode == 423 || error.code == 'NoteLocked') {
      emit(state.copyWith(status: EditorStatus.locked));
    } else if (error.statusCode == 404 ||
        (whileLoading && error.statusCode == 403)) {
      emit(
        state.copyWith(
          status: EditorStatus.unavailable,
          unavailableReason: _unavailable,
        ),
      );
    } else if (error.statusCode == 403) {
      _autosave.cancel();
      emit(
        state.copyWith(
          permissionLost: true,
          saveStatus: SaveStatus.failed,
          saveError: 'You can no longer edit this note.',
        ),
      );
    } else if (whileLoading) {
      // Offline with a cached copy: keep editing it locally.
      if (state.status != EditorStatus.ready) {
        emit(
          state.copyWith(
            status: EditorStatus.unavailable,
            unavailableReason: error.message,
          ),
        );
      }
    } else {
      emit(
        state.copyWith(
          saveStatus: SaveStatus.failed,
          saveError: error.message,
          newerVersionAvailable: error.code == 'VersionConflict' ? true : null,
        ),
      );
    }
  }

  Future<void> _unlock(
    EditorUnlockRequested event,
    Emitter<NoteEditorState> emit,
  ) async {
    emit(state.copyWith(unlocking: true));
    try {
      final note = await _store.unlock(noteId, event.password);
      emit(
        _withNote(
          state,
          note,
        ).copyWith(status: EditorStatus.ready, unlocking: false),
      );
    } on RepositoryException catch (error) {
      emit(
        state.copyWith(
          unlocking: false,
          unlockError: error.statusCode == 429
              ? 'Too many attempts. Wait a moment and try again.'
              : error.message,
        ),
      );
    }
  }

  Future<void> _keepMine(
    EditorKeepMineRequested event,
    Emitter<NoteEditorState> emit,
  ) async {
    final base = state.note;
    if (base == null) return;
    try {
      final version = await _store.latestVersion(noteId);
      emit(
        state.copyWith(
          note: base.copyWith(version: version),
          newerVersionAvailable: false,
        ),
      );
      await _save(emit);
    } on RepositoryException catch (error) {
      emit(state.copyWith(saveError: error.message));
    }
  }

  Future<void> _togglePin(
    EditorPinToggled event,
    Emitter<NoteEditorState> emit,
  ) async {
    final base = state.note;
    if (base == null || state.isNew || !base.isOwned) return;
    final pinned = !base.isPinned;
    try {
      await _store.setPinned(base, pinned);
      emit(state.copyWith(note: base.withPin(pinned)));
    } on RepositoryException catch (error) {
      emit(state.copyWith(saveError: error.message));
    }
  }

  Future<void> _setLabels(
    EditorLabelsChanged event,
    Emitter<NoteEditorState> emit,
  ) async {
    final base = state.note;
    if (base == null || !base.isOwned) return;
    if (state.isNew) {
      emit(state.copyWith(note: base.copyWith(labelIds: event.labelIds)));
      return;
    }
    try {
      await _store.setLabels(base, event.labelIds);
      emit(state.copyWith(note: base.copyWith(labelIds: event.labelIds)));
    } on RepositoryException catch (error) {
      emit(state.copyWith(saveError: error.message));
    }
  }

  Future<void> _delete(
    EditorDeleteRequested event,
    Emitter<NoteEditorState> emit,
  ) async {
    _autosave.cancel();
    if (state.isNew) {
      emit(state.copyWith(deleted: true));
      return;
    }
    try {
      await _store.delete(noteId);
      emit(state.copyWith(deleted: true));
    } on RepositoryException catch (error) {
      emit(state.copyWith(saveError: error.message));
    }
  }

  Future<void> _remote(
    EditorRemoteEvent event,
    Emitter<NoteEditorState> emit,
  ) async {
    final data = event.event;
    switch (data['type']) {
      case 'presence':
        final users = data['users'] as List? ?? const [];
        emit(
          state.copyWith(
            presence: [
              for (final user in users.whereType<Map>())
                if ('${user['displayName'] ?? ''}'.isNotEmpty)
                  '${user['displayName']}',
            ],
          ),
        );
      case 'noteChanged':
        final version = (data['version'] as num?)?.toInt() ?? 0;
        if (version <= (state.note?.version ?? 0)) return;
        if (data['isProtected'] == true &&
            !(state.note?.isProtected ?? false)) {
          emit(state.copyWith(status: EditorStatus.locked));
        } else if (_saving) {
          // Possibly our own save echoing back; decide once it returns.
          _remoteVersionDuringSave = version;
        } else if (state.isDirty) {
          emit(state.copyWith(newerVersionAvailable: true));
        } else {
          await _load(emit, replaceDraft: true);
        }
      case 'permissionChanged':
        final canEdit = const {'Edit', 'Owner'}.contains(data['permission']);
        if (!canEdit) _autosave.cancel();
        emit(state.copyWith(permissionLost: !canEdit));
        if (canEdit) await _load(emit, replaceDraft: !state.isDirty);
      case 'accessRevoked':
        _autosave.cancel();
        // Sync reports a note protected elsewhere this way; access remains,
        // only the content must be unlocked again.
        if (data['isProtected'] == true) {
          emit(state.copyWith(status: EditorStatus.locked));
          return;
        }
        emit(
          state.copyWith(
            status: EditorStatus.unavailable,
            unavailableReason: 'The owner removed your access to this note.',
          ),
        );
    }
  }

  static NoteEditorState _withNote(NoteEditorState state, JotterNote note) =>
      state.copyWith(note: note, title: note.title, content: note.content);

  /// Saves any unsaved text before the editor goes away.
  @override
  Future<void> close() async {
    _autosave.dispose();
    await _events?.cancel();
    final draft = state;
    final unsaved = draft.isDirty || draft.isNew;
    if (!draft.deleted && draft.canEdit && draft.hasText && unsaved) {
      try {
        await _store.save(
          draft.note!.copyWith(title: draft.title, content: draft.content),
          isNew: draft.isNew,
        );
      } catch (_) {
        // The offline outbox keeps whatever reached it.
      }
    }
    unawaited(_store.watch(null));
    return super.close();
  }
}
