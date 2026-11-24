sealed class NoteEditorEvent {
  const NoteEditorEvent();
}

final class EditorStarted extends NoteEditorEvent {
  const EditorStarted();
}

final class EditorTitleChanged extends NoteEditorEvent {
  const EditorTitleChanged(this.title);
  final String title;
}

final class EditorContentChanged extends NoteEditorEvent {
  const EditorContentChanged(this.content);
  final String content;
}

/// Saves now instead of waiting for the typing pause (leaving, backgrounding).
final class EditorFlushRequested extends NoteEditorEvent {
  const EditorFlushRequested();
}

final class EditorUnlockRequested extends NoteEditorEvent {
  const EditorUnlockRequested(this.password);
  final String password;
}

final class EditorReloadRequested extends NoteEditorEvent {
  const EditorReloadRequested();
}

/// Keeps the local draft over a newer server version and saves it on top.
final class EditorKeepMineRequested extends NoteEditorEvent {
  const EditorKeepMineRequested();
}

final class EditorPinToggled extends NoteEditorEvent {
  const EditorPinToggled();
}

final class EditorLabelsChanged extends NoteEditorEvent {
  const EditorLabelsChanged(this.labelIds);
  final List<String> labelIds;
}

final class EditorDeleteRequested extends NoteEditorEvent {
  const EditorDeleteRequested();
}

final class EditorRemoteEvent extends NoteEditorEvent {
  const EditorRemoteEvent(this.event);
  final Map<String, dynamic> event;
}

/// Raised by the bloc itself once typing has paused.
final class EditorAutosaveDue extends NoteEditorEvent {
  const EditorAutosaveDue();
}
