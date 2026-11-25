import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:jotter/models/jotter_account.dart';

/// A saved change the rest of the app should reflect.
class ProfileUpdate {
  const ProfileUpdate(this.account, {this.avatarChanged = false, this.avatar});

  final JotterAccount account;
  final bool avatarChanged;
  final Uint8List? avatar;
}

class EditProfileState extends Equatable {
  const EditProfileState({
    this.busy = false,
    this.error,
    this.notice,
    this.update,
  });

  final bool busy;
  final String? error;
  final String? notice;
  final ProfileUpdate? update;

  @override
  List<Object?> get props => [busy, error, notice, update];
}
