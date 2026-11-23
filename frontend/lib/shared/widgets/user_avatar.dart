import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.image,
    this.radius = 16,
  });

  final String name;
  final Uint8List? image;
  final double radius;

  String get _initial =>
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: context.jotterColors.tint(JotterColors.peach),
    foregroundImage: image == null ? null : MemoryImage(image!),
    onForegroundImageError: image == null ? null : (_, _) {},
    child: Text(
      _initial,
      style: TextStyle(
        fontSize: radius * .8,
        fontWeight: FontWeight.w600,
        color: JotterColors.accent,
      ),
    ),
  );
}
