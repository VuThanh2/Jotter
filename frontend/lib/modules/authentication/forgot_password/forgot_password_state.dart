import 'package:equatable/equatable.dart';

enum ResetStep { email, code, newPassword, done }

class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.step = ResetStep.email,
    this.email = '',
    this.ticket,
    this.busy = false,
    this.error,
  });

  final ResetStep step;
  final String email;
  final String? ticket;
  final bool busy;
  final String? error;

  ForgotPasswordState copyWith({
    ResetStep? step,
    String? email,
    String? ticket,
    bool? busy,
    String? error,
  }) => ForgotPasswordState(
    step: step ?? this.step,
    email: email ?? this.email,
    ticket: ticket ?? this.ticket,
    busy: busy ?? this.busy,
    error: error,
  );

  @override
  List<Object?> get props => [step, email, ticket, busy, error];
}
