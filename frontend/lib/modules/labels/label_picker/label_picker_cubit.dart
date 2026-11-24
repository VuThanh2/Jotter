import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/modules/labels/label_picker/label_picker_state.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';

class LabelPickerCubit extends Cubit<LabelPickerState> {
  LabelPickerCubit(this._store, Iterable<String> selected)
    : super(LabelPickerState(selected: selected.toSet())) {
    _subscription = _store.watchLabels().listen((labels) {
      if (!isClosed) emit(state.copyWith(labels: labels, error: state.error));
    });
  }

  final LabelStore _store;
  late final StreamSubscription<List<JotterLabel>> _subscription;

  void toggle(String labelId) {
    final selected = {...state.selected};
    if (!selected.remove(labelId)) selected.add(labelId);
    emit(state.copyWith(selected: selected));
  }

  Future<void> create(String name) async {
    try {
      final label = await _store.create(name);
      if (!isClosed) {
        emit(state.copyWith(selected: {...state.selected, label.id}));
      }
    } on RepositoryException catch (error) {
      if (!isClosed) emit(state.copyWith(error: error.message));
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
