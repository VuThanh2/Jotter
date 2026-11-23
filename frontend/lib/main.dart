import 'package:flutter/material.dart';

import 'data/note_repository.dart';
import 'models/jotter_preferences.dart';
import 'screens/workspace_screen.dart';
import 'theme.dart';

void main() => runApp(const JotterApp());

class JotterApp extends StatefulWidget {
  const JotterApp({super.key, this.repository});
  final NoteRepository? repository;

  @override
  State<JotterApp> createState() => _JotterAppState();
}

class _JotterAppState extends State<JotterApp> {
  JotterPreferences _preferences = const JotterPreferences();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Jotter — A space for your thoughts',
    debugShowCheckedModeBanner: false,
    theme: jotterTheme,
    darkTheme: jotterDarkTheme,
    themeMode: switch (_preferences.themeMode) {
      'Dark' => ThemeMode.dark,
      'Light' => ThemeMode.light,
      _ => ThemeMode.system,
    },
    home: WorkspaceScreen(
      repository: widget.repository,
      preferences: _preferences,
      onPreferencesChanged: (value) => setState(() => _preferences = value),
    ),
  );
}
