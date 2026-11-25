import 'package:equatable/equatable.dart';
import 'package:jotter/models/jotter_label.dart';

class LabelPickerState extends Equatable {
  const LabelPickerState({
    this.labels = const [],
    this.selected = const {},
    this.error,
  });

  final List<JotterLabel> labels;
  final Set<String> selected;
  final String? error;

  LabelPickerState copyWith({
    List<JotterLabel>? labels,
    Set<String>? selected,
    String? error,
  }) => LabelPickerState(
    labels: labels ?? this.labels,
    selected: selected ?? this.selected,
    error: error,
  );

  @override
  List<Object?> get props => [
    [for (final label in labels) '${label.id}:${label.name}'],
    selected,
    error,
  ];
}
