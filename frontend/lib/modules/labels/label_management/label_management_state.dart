import 'package:equatable/equatable.dart';
import 'package:jotter/models/jotter_label.dart';

enum LabelsStatus { loading, ready, failure }

class LabelManagementState extends Equatable {
  const LabelManagementState({
    this.status = LabelsStatus.loading,
    this.labels = const [],
    this.noteCounts = const {},
    this.busy = false,
    this.error,
  });

  final LabelsStatus status;
  final List<JotterLabel> labels;
  final Map<String, int> noteCounts;
  final bool busy;
  final String? error;

  LabelManagementState copyWith({
    LabelsStatus? status,
    List<JotterLabel>? labels,
    Map<String, int>? noteCounts,
    bool? busy,
    String? error,
  }) => LabelManagementState(
    status: status ?? this.status,
    labels: labels ?? this.labels,
    noteCounts: noteCounts ?? this.noteCounts,
    busy: busy ?? this.busy,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    [for (final label in labels) '${label.id}:${label.name}'],
    noteCounts,
    busy,
    error,
  ];
}
