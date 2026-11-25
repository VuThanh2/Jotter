import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';

/// The Jotter logo: a tilted note icon followed by the word mark.
class JotterMark extends StatelessWidget {
  const JotterMark({super.key, this.size = 29, this.showWord = true});

  final double size;
  final bool showWord;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Jotter',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -.1,
          child: Container(
            width: size * 1.17,
            height: size * 1.3,
            decoration: BoxDecoration(
              color: JotterColors.accent,
              borderRadius: BorderRadius.circular(size * .28),
            ),
            child: Icon(
              Icons.edit_note_rounded,
              color: Colors.white,
              size: size,
            ),
          ),
        ),
        if (showWord) ...[
          SizedBox(width: size * .38),
          Text.rich(
            const TextSpan(
              text: 'jotter',
              children: [
                TextSpan(
                  text: '.',
                  style: TextStyle(color: JotterColors.accent),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w700,
              letterSpacing: -size * .05,
            ),
          ),
        ],
      ],
    ),
  );
}
