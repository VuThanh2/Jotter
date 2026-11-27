import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/modules/ai/ask_ai/ask_ai_api.dart';
import 'package:jotter/modules/ai/ask_ai/ask_ai_state.dart';

class AskAiCubit extends Cubit<AskAiState> {
  AskAiCubit(this._api) : super(const AskAiState());

  final AskAiApi _api;

  Future<void> ask(String question) async {
    final trimmed = question.trim();
    if (state.asking || trimmed.isEmpty) return;
    // The previous answer stays visible until the new one arrives.
    emit(
      AskAiState(asking: true, question: state.question, answer: state.answer),
    );
    try {
      final answer = await _api.ask(trimmed);
      if (!isClosed) emit(AskAiState(question: trimmed, answer: answer));
    } catch (error) {
      if (!isClosed) {
        emit(
          AskAiState(
            question: state.question,
            answer: state.answer,
            error: error is RepositoryException
                ? error.message
                : 'Could not get an answer. Please try again.',
          ),
        );
      }
    }
  }
}
