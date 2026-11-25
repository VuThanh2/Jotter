import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/models/jotter_account.dart';
import 'package:jotter/modules/profile/shared/me_api.dart';
import 'package:jotter/modules/profile/shared/me_state.dart';

/// The signed-in user for the whole session.
class MeCubit extends Cubit<MeState> {
  MeCubit(this._api, {required this.onAccountChanged})
    : super(MeState(account: _api.cachedAccount));

  final MeApi _api;

  /// Lets the session persist account changes for the next app start.
  final void Function() onAccountChanged;

  Future<void> refresh() async {
    try {
      final account = await _api.fetchProfile();
      if (isClosed) return;
      emit(state.copyWith(account: account));
      onAccountChanged();
      final avatar = await _api.fetchAvatar();
      if (!isClosed) {
        emit(state.copyWith(avatar: avatar, clearAvatar: avatar == null));
      }
    } catch (_) {
      // Offline: keep the cached account.
    }
  }

  void accountUpdated(JotterAccount account) {
    emit(state.copyWith(account: account));
    onAccountChanged();
  }

  void avatarUpdated(JotterAccount account, Uint8List? avatar) {
    emit(
      state.copyWith(
        account: account,
        avatar: avatar,
        clearAvatar: avatar == null,
      ),
    );
    onAccountChanged();
  }
}
