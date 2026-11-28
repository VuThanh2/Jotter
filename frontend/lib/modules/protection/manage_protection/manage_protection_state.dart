import 'package:equatable/equatable.dart';

class ManageProtectionState extends Equatable {
  const ManageProtectionState({this.busy = false, this.error});

  final bool busy;
  final String? error;

  @override
  List<Object?> get props => [busy, error];
}
