import '../models/jotter_label.dart';
import '../models/jotter_note.dart';
import 'note_ids.dart';
import 'note_repository.dart';

/// An explicitly temporary workspace. No account or server data is used.
class PreviewNoteRepository extends NoteRepository {
  PreviewNoteRepository() {
    final now = DateTime.now();
    _labels.addAll(const [
      JotterLabel(id: 'work', name: 'Work'),
      JotterLabel(id: 'personal', name: 'Personal'),
      JotterLabel(id: 'ideas', name: 'Ideas'),
    ]);
    final samples =
        <({String title, String content, List<String> labels, bool pinned})>[
          (
            title: 'A little room for big ideas',
            content: 'Welcome to your quieter corner of the internet.\n\nA place for the thought you do not want to lose, the project taking shape, and all the little things in between.\n\nMake yourself at home. Create a note, give it a label, and keep what matters close.\n\nYou are exploring a preview workspace. Changes stay here for this session; sign in to keep notes in your account.',
            labels: ['ideas'],
            pinned: true,
          ),
          (
            title: 'The week, gently planned',
            content: 'Three things to make room for this week:\n\n☐ Finish the first draft of the brand story\n☐ Take a proper lunch break, away from the screen\n☐ Send the proposal before Thursday\n\nA small reminder: progress does not have to be loud.',
            labels: ['work'],
            pinned: true,
          ),
          (
            title: 'A few things worth making',
            content: 'A reading lamp that feels like a little sunset.\n\nA neighborhood map made entirely of recommendations from friends.\n\nA recipe book with room for the stories behind the food.\n\nA Sunday with no notifications. Start with that one.',
            labels: ['ideas'],
            pinned: false,
          ),
          (
            title: 'Notes from a slow Sunday',
            content: 'Coffee at the little place on the corner. A long walk without a destination. The kind of light that makes even an ordinary street look like a photograph.\n\nRemember to do this more often.\n\nCurrently reading: The Creative Act\nCurrently listening: a very good jazz playlist\nCurrently grateful for: unhurried mornings',
            labels: ['personal'],
            pinned: false,
          ),
          (
            title: 'A better kind of meeting',
            content: 'Studio catch-up · Tuesday\n\nWhat we talked about\n• Give the onboarding flow a little more breathing room\n• Lead with the value, then explain the details\n• Use real words. Keep things simple.\n\nNext steps\n• Sketch two directions for the welcome screen\n• Gather feedback from the team\n• Leave time to make it feel right',
            labels: ['work', 'ideas'],
            pinned: false,
          ),
          (
            title: 'The weekend table',
            content: 'For the market\n\n• Ripe tomatoes\n• Fresh basil and a good loaf of bread\n• Lemons\n• Something in season that looks too good to leave behind\n\nFor the table\n\nGood olive oil, a few friends, and absolutely no rush.',
            labels: ['personal'],
            pinned: false,
          ),
        ];
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final date = now.subtract(Duration(hours: index * 4 + 1));
      final note = JotterNote(
        id: newNoteId(),
        title: sample.title,
        content: sample.content,
        preview: _preview(sample.content),
        version: 1,
        createdAt: date.subtract(const Duration(days: 2)),
        updatedAt: date,
        isPinned: sample.pinned,
        labelIds: sample.labels,
      );
      _notes[note.id] = note;
    }
  }

  final Map<String, JotterNote> _notes = {};
  final List<JotterLabel> _labels = [];

  @override
  bool get isPreview => true;

  @override
  Future<List<JotterNote>> listNotes({String? query}) async {
    final search = query?.trim().toLowerCase() ?? '';
    final notes = _notes.values.where((note) {
      return search.isEmpty ||
          note.title.toLowerCase().contains(search) ||
          (!note.isProtected && note.content.toLowerCase().contains(search));
    }).toList();
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return notes;
  }

  @override
  Future<JotterNote> getNote(String id) async {
    final note = _notes[id];
    if (note == null) {
      throw const RepositoryException(
        'This note no longer exists.',
        statusCode: 404,
      );
    }
    return note;
  }

  @override
  Future<List<JotterLabel>> listLabels() async => List.unmodifiable(_labels);

  @override
  Future<JotterNote> saveNote(JotterNote note, {bool isNew = false}) async {
    validateNote(note);
    if (!note.canEdit) {
      throw const RepositoryException(
        'You have read-only access to this note.',
      );
    }
    final previous = _notes[note.id];
    if (!isNew && previous == null) {
      throw const RepositoryException(
        'This note no longer exists.',
        statusCode: 404,
      );
    }
    if (isNew && previous != null) {
      throw const RepositoryException(
        'This note already exists.',
        statusCode: 409,
      );
    }
    if (previous != null && previous.version != note.version) {
      throw const RepositoryException(
        'This note changed elsewhere. Your draft is still here. Copy it before reloading.',
        statusCode: 409,
        code: 'VersionConflict',
      );
    }
    final saved = note.copyWith(
      preview: note.isProtected ? '' : _preview(note.content),
      version: (previous?.version ?? 0) + 1,
      updatedAt: DateTime.now(),
      contentLoaded: true,
    );
    _notes[note.id] = saved;
    return saved;
  }

  @override
  Future<JotterNote> pinNote(JotterNote note, bool pinned) async {
    final current = await getNote(note.id);
    final saved = current.copyWith(isPinned: pinned);
    _notes[note.id] = saved;
    return saved;
  }

  @override
  Future<void> deleteNote(String id) async {
    await getNote(id);
    _notes.remove(id);
  }

  @override
  Future<JotterLabel> createLabel(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      throw const RepositoryException(
        'Use a label name between 1 and 50 characters.',
      );
    }
    if (_labels.any(
      (label) => label.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      throw const RepositoryException('A label with this name already exists.');
    }
    final label = JotterLabel(id: newNoteId(), name: trimmed);
    _labels.add(label);
    return label;
  }

  @override
  Future<JotterNote> setLabels(JotterNote note, List<String> ids) async {
    final current = await getNote(note.id);
    if (ids.any((id) => !_labels.any((label) => label.id == id))) {
      throw const RepositoryException('One of these labels no longer exists.');
    }
    final saved = current.copyWith(labelIds: ids.toSet().toList());
    _notes[note.id] = saved;
    return saved;
  }

  @override
  Future<JotterLabel> renameLabel(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50)
      throw const RepositoryException('Use 1–50 characters for a label.');
    if (_labels.any(
      (label) =>
          label.id != id && label.name.toLowerCase() == trimmed.toLowerCase(),
    ))
      throw const RepositoryException('A label with this name already exists.');
    final index = _labels.indexWhere((label) => label.id == id);
    if (index < 0)
      throw const RepositoryException('This label no longer exists.');
    final label = JotterLabel(id: id, name: trimmed);
    _labels[index] = label;
    return label;
  }

  @override
  Future<void> deleteLabel(String id) async {
    _labels.removeWhere((label) => label.id == id);
    for (final entry in _notes.entries.toList()) {
      _notes[entry.key] = entry.value.copyWith(
        labelIds: entry.value.labelIds
            .where((labelId) => labelId != id)
            .toList(),
      );
    }
  }

  @override
  Future<JotterNote> unlockNote(String id, String password) => getNote(id);

  @override
  Future<void> close() async {
    _notes.clear();
    _labels.clear();
  }

  static String _preview(String content) =>
      content.length > 200 ? content.substring(0, 200) : content;
}
