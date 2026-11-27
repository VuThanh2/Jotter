import 'package:equatable/equatable.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/models/jotter_note.dart';

enum NotesStatus { loading, ready, failure }

class NotesHomeState extends Equatable {
  const NotesHomeState({
    this.status = NotesStatus.loading,
    this.notes = const [],
    this.labels = const [],
    this.query = '',
    this.searchResults,
    this.searching = false,
    this.refreshing = false,
    this.selectedLabelIds = const {},
    this.error,
    this.revision = 0,
  });

  final NotesStatus status;
  final List<JotterNote> notes;
  final List<JotterLabel> labels;
  final String query;

  /// Server results for [query]; shared notes may appear here too.
  final List<JotterNote>? searchResults;
  final bool searching;
  final bool refreshing;
  final Set<String> selectedLabelIds;
  final String? error;

  /// Bumped on every data change so equal-looking lists still rebuild.
  final int revision;

  bool get isSearching => query.trim().isNotEmpty;
  bool get isFiltering => selectedLabelIds.isNotEmpty;

  List<JotterNote> get visible {
    final source = isSearching
        ? searchResults ?? const <JotterNote>[]
        : notes.where((note) => note.isOwned);
    return source
        .where(
          (note) =>
              !isFiltering || note.labelIds.any(selectedLabelIds.contains),
        )
        .toList();
  }

  List<JotterNote> get pinned =>
      visible.where((note) => note.isPinned).toList()..sort(_byPinTime);

  List<JotterNote> get others =>
      visible.where((note) => !note.isPinned).toList()..sort(_byUpdated);

  static int _byUpdated(JotterNote a, JotterNote b) =>
      b.updatedAt.compareTo(a.updatedAt);

  /// Most recently pinned first, matching the server order.
  static int _byPinTime(JotterNote a, JotterNote b) {
    final pinned = (b.pinnedAt ?? b.updatedAt).compareTo(
      a.pinnedAt ?? a.updatedAt,
    );
    return pinned != 0 ? pinned : _byUpdated(a, b);
  }

  NotesHomeState copyWith({
    NotesStatus? status,
    List<JotterNote>? notes,
    List<JotterLabel>? labels,
    String? query,
    List<JotterNote>? searchResults,
    bool clearSearchResults = false,
    bool? searching,
    bool? refreshing,
    Set<String>? selectedLabelIds,
    String? error,
  }) => NotesHomeState(
    status: status ?? this.status,
    notes: notes ?? this.notes,
    labels: labels ?? this.labels,
    query: query ?? this.query,
    searchResults: clearSearchResults
        ? null
        : searchResults ?? this.searchResults,
    searching: searching ?? this.searching,
    refreshing: refreshing ?? this.refreshing,
    selectedLabelIds: selectedLabelIds ?? this.selectedLabelIds,
    error: error,
    revision: revision + 1,
  );

  @override
  List<Object?> get props => [
    status,
    query,
    searching,
    selectedLabelIds,
    error,
    revision,
  ];
}
