import 'package:equatable/equatable.dart';
import 'package:jotter/models/jotter_label.dart';

class LabelManagementState extends Equatable {
  const LabelManagementState({
    this.labels = const [],
    this.noteCounts = const {},
    this.busy = false,
    this.error,
  });

  final List<JotterLabel> labels;
  final Map<String, int> noteCounts;
  final bool busy;
  final String? error;

  LabelManagementState copyWith({
    List<JotterLabel>? labels,
    Map<String, int>? noteCounts,
    bool? busy,
    String? error,
  }) => LabelManagementState(
    labels: labels ?? this.labels,
    noteCounts: noteCounts ?? this.noteCounts,
    busy: busy ?? this.busy,
    error: error,
  );

  @override
  List<Object?> get props => [
    [for (final label in labels) '${label.id}:${label.name}'],
    noteCounts,
    busy,
    error,
  ];
}
