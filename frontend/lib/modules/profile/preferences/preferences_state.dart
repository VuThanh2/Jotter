import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:jotter/models/jotter_preferences.dart';

class PreferencesState extends Equatable {
  const PreferencesState({
    this.preferences = const JotterPreferences(),
    this.pendingSync = false,
  });

  final JotterPreferences preferences;

  /// Saved on this device but not yet on the server.
  final bool pendingSync;

  ThemeMode get themeMode => switch (preferences.themeMode) {
    'Dark' => ThemeMode.dark,
    'Light' => ThemeMode.light,
    _ => ThemeMode.system,
  };

  bool get listMode => preferences.listViewMode == 'List';

  double get noteFontSize => preferences.noteFontSize.clamp(12, 32).toDouble();

  /// Null keeps the theme's default card surface.
  Color? get noteColor {
    final hex = preferences.defaultNoteColor.toUpperCase();
    if (hex == '#FFFFFF' || !RegExp(r'^#[0-9A-F]{6}$').hasMatch(hex)) {
      return null;
    }
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  @override
  List<Object?> get props => [
    preferences.noteFontSize,
    preferences.defaultNoteColor,
    preferences.themeMode,
    preferences.listViewMode,
    pendingSync,
  ];
}
