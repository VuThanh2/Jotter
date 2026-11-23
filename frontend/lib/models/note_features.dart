class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
  });
  factory NoteAttachment.fromJson(Map<String, dynamic> json) => NoteAttachment(
    id: json['attachmentId'] as String,
    name: json['fileName'] as String,
    mimeType: json['mimeType'] as String,
    sizeBytes: (json['sizeBytes'] as num).toInt(),
    uploadedAt: DateTime.parse(json['uploadedAt'] as String),
  );
  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;
  bool get isImage => const [
    'image/png',
    'image/jpeg',
    'image/gif',
    'image/webp',
  ].contains(mimeType);
  String get sizeLabel => sizeBytes < 1024
      ? '$sizeBytes B'
      : sizeBytes < 1024 * 1024
      ? '${(sizeBytes / 1024).toStringAsFixed(1)} KB'
      : '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class NoteShare {
  const NoteShare({
    required this.id,
    required this.email,
    required this.displayName,
    required this.permission,
  });
  factory NoteShare.fromJson(Map<String, dynamic> json) => NoteShare(
    id: json['shareId'] as String,
    email: json['recipientEmail'] as String,
    displayName: json['recipientDisplayName'] as String? ?? '',
    permission: json['permission'] as String,
  );
  final String id;
  final String email;
  final String displayName;
  final String permission;
}

class ShareInvitationResult {
  const ShareInvitationResult(this.created, this.rejected);
  final int created;
  final List<({String email, String code})> rejected;
}

class NoteSummary {
  const NoteSummary(this.text, this.generatedAt);
  factory NoteSummary.fromJson(Map<String, dynamic> json) => NoteSummary(
    json['summaryText'] as String,
    DateTime.parse(json['generatedAt'] as String),
  );
  final String text;
  final DateTime generatedAt;
}

class SummaryEvent {
  const SummaryEvent({
    required this.kind,
    this.text = '',
    this.generatedAt,
    this.code,
    this.message,
  });
  final String kind;
  final String text;
  final DateTime? generatedAt;
  final String? code;
  final String? message;
}

class NoteCitation {
  const NoteCitation({
    required this.noteId,
    required this.title,
    required this.excerpt,
  });
  factory NoteCitation.fromJson(Map<String, dynamic> json) => NoteCitation(
    noteId: json['noteId'] as String,
    title: json['title'] as String,
    excerpt: json['excerpt'] as String,
  );
  final String noteId;
  final String title;
  final String excerpt;
}

class NotesAnswer {
  const NotesAnswer({
    required this.answer,
    required this.hasEnoughContext,
    required this.citations,
  });
  factory NotesAnswer.fromJson(Map<String, dynamic> json) => NotesAnswer(
    answer: json['answer'] as String,
    hasEnoughContext: json['hasEnoughContext'] as bool,
    citations: (json['citations'] as List)
        .map((item) => NoteCitation.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
  final String answer;
  final bool hasEnoughContext;
  final List<NoteCitation> citations;
}
