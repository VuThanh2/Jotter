class JotterNote {
  JotterNote({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.createdAt,
    this.preview = '',
    this.version = 0,
    this.isPinned = false,
    this.isProtected = false,
    this.isShared = false,
    this.canEdit = true,
    this.isOwned = true,
    this.contentLoaded = true,
    this.conflictOfNoteId,
    List<String> labelIds = const [],
  }) : labelIds = List.unmodifiable(labelIds);

  final String id;
  final String title;
  final String content;
  final String preview;
  final int version;
  final DateTime updatedAt;
  final DateTime createdAt;
  final bool isPinned;
  final bool isProtected;
  final bool isShared;
  final bool canEdit;
  final bool isOwned;
  final bool contentLoaded;
  final String? conflictOfNoteId;
  final List<String> labelIds;

  JotterNote copyWith({
    String? id,
    String? title,
    String? content,
    String? preview,
    int? version,
    DateTime? updatedAt,
    DateTime? createdAt,
    bool? isPinned,
    bool? isProtected,
    bool? isShared,
    bool? canEdit,
    bool? isOwned,
    bool? contentLoaded,
    List<String>? labelIds,
    String? conflictOfNoteId,
  }) => JotterNote(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    preview: preview ?? this.preview,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt ?? this.createdAt,
    isPinned: isPinned ?? this.isPinned,
    isProtected: isProtected ?? this.isProtected,
    isShared: isShared ?? this.isShared,
    canEdit: canEdit ?? this.canEdit,
    isOwned: isOwned ?? this.isOwned,
    contentLoaded: contentLoaded ?? this.contentLoaded,
    labelIds: labelIds ?? this.labelIds,
    conflictOfNoteId: conflictOfNoteId ?? this.conflictOfNoteId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'preview': preview,
    'version': version,
    'updatedAt': updatedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'isPinned': isPinned,
    'isProtected': isProtected,
    'isShared': isShared,
    'canEdit': canEdit,
    'isOwned': isOwned,
    'contentLoaded': contentLoaded,
    'labelIds': labelIds,
    'conflictOfNoteId': conflictOfNoteId,
  };

  factory JotterNote.fromJson(Map<String, dynamic> json) => JotterNote(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    preview: json['preview'] as String? ?? '',
    version: (json['version'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    isPinned: json['isPinned'] as bool? ?? false,
    isProtected: json['isProtected'] as bool? ?? false,
    isShared: json['isShared'] as bool? ?? false,
    canEdit: json['canEdit'] as bool? ?? false,
    isOwned: json['isOwned'] as bool? ?? false,
    contentLoaded: json['contentLoaded'] as bool? ?? false,
    conflictOfNoteId: json['conflictOfNoteId'] as String?,
    labelIds: List<String>.from(json['labelIds'] as List? ?? []),
  );
}
