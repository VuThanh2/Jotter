import 'package:equatable/equatable.dart';
import 'package:jotter/models/note_features.dart';

class AskAiState extends Equatable {
  const AskAiState({
    this.asking = false,
    this.question,
    this.answer,
    this.error,
  });

  final bool asking;

  /// The question [answer] responds to.
  final String? question;
  final NotesAnswer? answer;
  final String? error;

  @override
  List<Object?> get props => [asking, question, answer, error];
}
