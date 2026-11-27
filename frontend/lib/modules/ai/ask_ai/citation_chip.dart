import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/note_features.dart';

/// A source note behind an answer; tapping opens that note.
class CitationChip extends StatefulWidget {
  const CitationChip({super.key, required this.citation, required this.onOpen});

  final NoteCitation citation;
  final VoidCallback onOpen;

  @override
  State<CitationChip> createState() => _CitationChipState();
}

class _CitationChipState extends State<CitationChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final citation = widget.citation;
    final title = citation.title.isEmpty ? 'Untitled note' : citation.title;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      // The same keyboard focus ring as note cards and buttons.
      shape: _focused
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.jotterColors.ink, width: 2),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onOpen,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: Semantics(
          button: true,
          label: 'Open note $title',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: context.jotterColors.muted,
                    ),
                  ],
                ),
                if (citation.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    citation.excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.jotterColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
