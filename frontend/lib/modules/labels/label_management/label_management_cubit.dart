import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/modules/labels/label_management/label_management_state.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';

class LabelManagementCubit extends Cubit<LabelManagementState> {
  LabelManagementCubit(this._store) : super(const LabelManagementState()) {
    _subscription = _store.watchLabels().listen(_show);
  }

  final LabelStore _store;
  late final StreamSubscription<List<JotterLabel>> _subscription;

  void _show(List<JotterLabel> labels) {
    if (isClosed) return;
    emit(
      state.copyWith(
        labels: labels,
        noteCounts: {
          for (final label in labels) label.id: _store.noteCount(label.id),
        },
        error: state.error,
      ),
    );
  }

  Future<bool> create(String name) => _run(() => _store.create(name));

  Future<bool> rename(String id, String name) =>
      _run(() => _store.rename(id, name));

  Future<bool> delete(String id) => _run(() => _store.delete(id));

  Future<bool> _run(Future<void> Function() action) async {
    emit(state.copyWith(busy: true));
    try {
      await action();
      if (!isClosed) emit(state.copyWith(busy: false));
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            error: error is RepositoryException
                ? error.message
                : 'The label could not be saved. Try again.',
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
