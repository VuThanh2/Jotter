import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jotter/data/account_api.dart';
import 'package:jotter/modules/profile/edit_profile/edit_profile_api.dart';
import 'package:jotter/modules/profile/edit_profile/edit_profile_state.dart';
import 'package:jotter/shared/lib/file_service.dart';

class EditProfileCubit extends Cubit<EditProfileState> {
  EditProfileCubit(this._api, this._files) : super(const EditProfileState());

  static const maxAvatarBytes = 5 * 1024 * 1024;
  static const _avatarExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final EditProfileApi _api;
  final FileService _files;

  bool get supportsCamera => _files.supportsCamera;

  Future<void> rename(String displayName) => _run(() async {
    final account = await _api.rename(displayName);
    return (ProfileUpdate(account), 'Your name has been updated.');
  });

  Future<void> chooseAvatar(PickSource source) async {
    final XFile file;
    try {
      final picked = await _files.pickImage(source);
      if (picked == null) return;
      file = picked;
    } on PickPermissionDenied catch (error) {
      emit(EditProfileState(error: error.message));
      return;
    }
    final extension = file.name.split('.').last.toLowerCase();
    if (!_avatarExtensions.contains(extension)) {
      emit(const EditProfileState(error: 'Choose a JPEG, PNG or WebP image.'));
      return;
    }
    if (await file.length() > maxAvatarBytes) {
      emit(const EditProfileState(error: 'Choose an image smaller than 5 MB.'));
      return;
    }
    await _run(() async {
      final bytes = await file.readAsBytes();
      final account = await _api.uploadAvatar(bytes, file.name);
      return (
        ProfileUpdate(account, avatarChanged: true, avatar: bytes),
        'Your photo has been updated.',
      );
    });
  }

  Future<void> removeAvatar() => _run(() async {
    final account = await _api.removeAvatar();
    return (
      ProfileUpdate(account, avatarChanged: true),
      'Your photo has been removed.',
    );
  });

  Future<void> _run(Future<(ProfileUpdate, String)> Function() action) async {
    if (state.busy) return;
    emit(const EditProfileState(busy: true));
    try {
      final (update, notice) = await action();
      if (!isClosed) emit(EditProfileState(notice: notice, update: update));
    } catch (error) {
      if (!isClosed) emit(EditProfileState(error: accountErrorMessage(error)));
    }
  }
}
