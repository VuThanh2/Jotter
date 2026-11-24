import 'package:equatable/equatable.dart';

enum SubmitStatus { idle, submitting, success, failure }

/// State of a form that sends one request and may return a [result].
class SubmitState<T> extends Equatable {
  const SubmitState({this.status = SubmitStatus.idle, this.error, this.result});

  const SubmitState.submitting() : this(status: SubmitStatus.submitting);

  const SubmitState.success([T? result])
    : this(status: SubmitStatus.success, result: result);

  const SubmitState.failure(String error)
    : this(status: SubmitStatus.failure, error: error);

  final SubmitStatus status;
  final String? error;
  final T? result;

  bool get isSubmitting => status == SubmitStatus.submitting;
  bool get isSuccess => status == SubmitStatus.success;

  @override
  List<Object?> get props => [status, error, result];
}
