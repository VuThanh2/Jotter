class JotterPreferences {
  const JotterPreferences({
    this.noteFontSize = 16,
    this.defaultNoteColor = '#FFFFFF',
    this.themeMode = 'System',
    this.listViewMode = 'Grid',
  });
  factory JotterPreferences.fromJson(Map<String, dynamic> json) =>
      JotterPreferences(
        noteFontSize: (json['noteFontSize'] as num?)?.toInt() ?? 16,
        defaultNoteColor: json['defaultNoteColor'] as String? ?? '#FFFFFF',
        themeMode: json['themeMode'] as String? ?? 'System',
        listViewMode: json['listViewMode'] as String? ?? 'Grid',
      );
  final int noteFontSize;
  final String defaultNoteColor;
  final String themeMode;
  final String listViewMode;
  Map<String, dynamic> toJson() => {
    'noteFontSize': noteFontSize,
    'defaultNoteColor': defaultNoteColor,
    'themeMode': themeMode,
    'listViewMode': listViewMode,
  };
  JotterPreferences copyWith({
    int? noteFontSize,
    String? defaultNoteColor,
    String? themeMode,
    String? listViewMode,
  }) => JotterPreferences(
    noteFontSize: noteFontSize ?? this.noteFontSize,
    defaultNoteColor: defaultNoteColor ?? this.defaultNoteColor,
    themeMode: themeMode ?? this.themeMode,
    listViewMode: listViewMode ?? this.listViewMode,
  );
}
