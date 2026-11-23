import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/widgets/ask_notes_dialog.dart';

class AskAiPage extends StatelessWidget {
  const AskAiPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: AskNotesPanel(
            repository: context.read<ApiNoteRepository>(),
            onOpenNote: (noteId) async => context.push(AppRoutes.note(noteId)),
          ),
        ),
      ),
    ),
  );
}
