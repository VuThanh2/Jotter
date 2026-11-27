import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/modules/ai/summary/summary_api.dart';
import 'package:jotter/modules/ai/summary/summary_state.dart';

class SummaryCubit extends Cubit<SummaryState> {
  SummaryCubit(this._api, {required this.noteId}) : super(const SummaryState());

  final SummaryApi _api;
  final String noteId;
  StreamSubscription<SummaryEvent>? _stream;

  Future<void> load() async {
    emit(state.copyWith(status: SummaryStatus.loading));
    try {
      final saved = await _api.saved(noteId);
      if (isClosed) return;
      emit(
        SummaryState(
          status: SummaryStatus.ready,
          text: saved?.text ?? '',
          savedAt: saved?.generatedAt,
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(status: SummaryStatus.ready, error: _message(error)),
        );
      }
    }
  }

  Future<void> generate() async {
    if (state.generating) return;
    await _stream?.cancel();
    emit(
      state.copyWith(
        status: SummaryStatus.generating,
        text: '',
        clearSavedAt: true,
      ),
    );
    _stream = _api
        .generate(noteId)
        .listen(
          _onEvent,
          onError: (Object error) => _finish(error: _message(error)),
          onDone: _finish,
        );
  }

  Future<void> stop() async {
    await _stream?.cancel();
    _stream = null;
    if (!isClosed && state.generating) {
      emit(state.copyWith(status: SummaryStatus.ready));
    }
  }

  void _onEvent(SummaryEvent event) {
    if (isClosed) return;
    switch (event.kind) {
      case 'delta':
        emit(state.copyWith(text: state.text + event.text));
      case 'completed':
        emit(
          state.copyWith(
            status: SummaryStatus.ready,
            text: event.text,
            savedAt: event.generatedAt,
          ),
        );
      case 'failed':
        _finish(error: event.message ?? 'The summary could not be created.');
    }
  }

  void _finish({String? error}) {
    if (isClosed || !state.generating) return;
    emit(state.copyWith(status: SummaryStatus.ready, error: error));
  }

  static String _message(Object error) => error is RepositoryException
      ? error.message
      : 'The summary could not be created. Please try again.';

  @override
  Future<void> close() async {
    await _stream?.cancel();
    return super.close();
  }
}
