import 'package:equatable/equatable.dart';

enum SummaryStatus { loading, ready, generating }

class SummaryState extends Equatable {
  const SummaryState({
    this.status = SummaryStatus.loading,
    this.text = '',
    this.savedAt,
    this.error,
  });

  final SummaryStatus status;
  final String text;

  /// Set once the server has stored [text]; a stopped stream leaves it null.
  final DateTime? savedAt;
  final String? error;

  bool get generating => status == SummaryStatus.generating;
  bool get isPartial => !generating && text.isNotEmpty && savedAt == null;

  SummaryState copyWith({
    SummaryStatus? status,
    String? text,
    DateTime? savedAt,
    bool clearSavedAt = false,
    String? error,
  }) => SummaryState(
    status: status ?? this.status,
    text: text ?? this.text,
    savedAt: clearSavedAt ? null : savedAt ?? this.savedAt,
    error: error,
  );

  @override
  List<Object?> get props => [status, text, savedAt, error];
}
