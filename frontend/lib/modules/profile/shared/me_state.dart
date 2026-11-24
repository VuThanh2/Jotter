import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:jotter/models/jotter_account.dart';

class MeState extends Equatable {
  const MeState({required this.account, this.avatar});

  final JotterAccount account;
  final Uint8List? avatar;

  MeState copyWith({
    JotterAccount? account,
    Uint8List? avatar,
    bool clearAvatar = false,
  }) => MeState(
    account: account ?? this.account,
    avatar: clearAvatar ? null : avatar ?? this.avatar,
  );

  @override
  List<Object?> get props => [
    account.id,
    account.displayName,
    account.email,
    account.isActivated,
    account.avatarUrl,
    avatar,
  ];
}
