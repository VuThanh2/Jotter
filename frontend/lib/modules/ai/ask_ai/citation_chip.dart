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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final citation = widget.citation;
    final palette = context.jotterColors;
    final title = citation.title.isEmpty ? 'Untitled note' : citation.title;
    final radius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: JotterMotion.fast,
          decoration: BoxDecoration(
            color: _hovered ? palette.sidebar : palette.paper,
            borderRadius: radius,
            // The same keyboard focus ring as note cards and buttons.
            border: Border.all(
              color: _focused ? palette.ink : palette.line,
              width: _focused ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onOpen,
              onFocusChange: (focused) => setState(() => _focused = focused),
              child: Semantics(
                button: true,
                label: 'Open note $title',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: palette.tint(JotterColors.butter),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.sticky_note_2_outlined,
                          size: 18,
                          color: palette.muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (citation.excerpt.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                citation.excerpt,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSlide(
                        duration: JotterMotion.fast,
                        offset: Offset(_hovered ? .2 : 0, 0),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
