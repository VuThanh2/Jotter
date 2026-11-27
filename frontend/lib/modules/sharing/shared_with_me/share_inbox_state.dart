import 'package:equatable/equatable.dart';

/// A note someone just shared with this account.
class ShareAnnouncement extends Equatable {
  const ShareAnnouncement({
    required this.noteId,
    required this.title,
    required this.sharedBy,
    this.sharedAt,
    this.others = 0,
  });

  final String noteId;
  final String title;
  final String sharedBy;

  /// Tells a repeated share of the same note apart from the previous one.
  final DateTime? sharedAt;

  /// Further notes that arrived in the same sync.
  final int others;

  String get message {
    final who = sharedBy.isEmpty ? 'Someone' : sharedBy;
    final what = title.isEmpty ? 'a note' : '“$title”';
    final more = others == 0
        ? ''
        : ' and $others more ${others == 1 ? 'note' : 'notes'}';
    return '$who shared $what$more with you.';
  }

  @override
  List<Object?> get props => [noteId, title, sharedBy, sharedAt, others];
}

class ShareInboxState extends Equatable {
  const ShareInboxState({this.unviewed = 0, this.latest});

  /// Shared notes not yet seen in the Shared tab.
  final int unviewed;
  final ShareAnnouncement? latest;

  @override
  List<Object?> get props => [unviewed, latest];
}
