final _listMarker = RegExp(r'^(\s*)[*-]\s+', multiLine: true);
final _bold = RegExp(r'\*\*(.+?)\*\*');

/// AI replies use Markdown list and bold markers, which read as stray
/// asterisks in plain text.
String readableAiText(String text) => text
    .replaceAllMapped(_listMarker, (match) => '${match[1]}• ')
    .replaceAllMapped(_bold, (match) => match[1]!);
