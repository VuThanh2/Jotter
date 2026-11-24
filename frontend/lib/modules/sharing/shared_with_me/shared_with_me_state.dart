import 'package:equatable/equatable.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_api.dart';

class SharedWithMeState extends Equatable {
  const SharedWithMeState({
    this.loading = true,
    this.notes = const [],
    this.info = const {},
    this.query = '',
    this.revision = 0,
  });

  final bool loading;
  final List<JotterNote> notes;
  final Map<String, SharedNoteInfo> info;
  final String query;
  final int revision;

  List<JotterNote> get visible {
    final search = query.trim().toLowerCase();
    return notes
        .where(
          (note) =>
              search.isEmpty ||
              note.title.toLowerCase().contains(search) ||
              (!note.isProtected &&
                  note.preview.toLowerCase().contains(search)),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  SharedWithMeState copyWith({
    bool? loading,
    List<JotterNote>? notes,
    Map<String, SharedNoteInfo>? info,
    String? query,
  }) => SharedWithMeState(
    loading: loading ?? this.loading,
    notes: notes ?? this.notes,
    info: info ?? this.info,
    query: query ?? this.query,
    revision: revision + 1,
  );

  @override
  List<Object?> get props => [loading, query, revision];
}
