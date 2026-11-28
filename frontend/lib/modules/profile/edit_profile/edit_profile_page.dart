import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/modules/authentication/shared/auth_models.dart';
import 'package:jotter/modules/profile/edit_profile/edit_profile_api.dart';
import 'package:jotter/modules/profile/edit_profile/edit_profile_cubit.dart';
import 'package:jotter/modules/profile/edit_profile/edit_profile_state.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';
import 'package:jotter/modules/profile/shared/me_state.dart';
import 'package:jotter/modules/profile/shared/unverified_banner.dart';
import 'package:jotter/shared/lib/file_service.dart';
import 'package:jotter/shared/widgets/page_frame.dart';
import 'package:jotter/shared/widgets/state_views.dart';
import 'package:jotter/shared/widgets/user_avatar.dart';

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key, this.fileService});

  final FileService? fileService;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => EditProfileCubit(
      EditProfileApi(context.read<ApiNoteRepository>()),
      fileService ?? FileService(),
    ),
    child: const _EditProfileView(),
  );
}

class _EditProfileView extends StatefulWidget {
  const _EditProfileView();

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: context.read<MeCubit>().state.account.displayName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _saveName() {
    if (_form.currentState!.validate()) {
      context.read<EditProfileCubit>().rename(_name.text);
    }
  }

  void _applyUpdate(BuildContext context, EditProfileState state) {
    final update = state.update;
    if (update == null) return;
    final me = context.read<MeCubit>();
    if (update.avatarChanged) {
      me.avatarUpdated(update.account, update.avatar);
    } else {
      me.accountUpdated(update.account);
    }
  }

  Future<void> _changePhoto(bool hasPhoto) async {
    final cubit = context.read<EditProfileCubit>();
    if (!cubit.supportsCamera) {
      await cubit.chooseAvatar(PickSource.files);
      return;
    }
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, _PhotoChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, _PhotoChoice.camera),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(context, _PhotoChoice.remove),
              ),
          ],
        ),
      ),
    );
    switch (choice) {
      case _PhotoChoice.gallery:
        await cubit.chooseAvatar(PickSource.gallery);
      case _PhotoChoice.camera:
        await cubit.chooseAvatar(PickSource.camera);
      case _PhotoChoice.remove:
        await cubit.removeAvatar();
      case null:
        break;
    }
  }

  /// Avatar with its photo actions; a column card on desktop, the top of
  /// the form elsewhere.
  Widget _photo(BuildContext context, EditProfileState state, MeState me) {
    final hasPhoto = me.account.avatarUrl != null;
    final cubit = context.read<EditProfileCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.jotterColors.surface,
              shape: BoxShape.circle,
              boxShadow: context.jotterColors.softShadow,
            ),
            child: UserAvatar(
              name: me.account.displayName,
              image: me.avatar,
              radius: 46,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('change-photo'),
              onPressed: state.busy ? null : () => _changePhoto(hasPhoto),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(hasPhoto ? 'Change photo' : 'Add photo'),
            ),
            if (hasPhoto && !cubit.supportsCamera)
              TextButton(
                onPressed: state.busy ? null : cubit.removeAvatar,
                child: const Text('Remove'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'JPEG, PNG or WebP, up to 5 MB',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: context.jotterColors.muted),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    banner: const UnverifiedBanner(),
    title: 'Edit profile',
    subtitle: 'How you appear to people you share notes with.',
    icon: Icons.person_outline_rounded,
    fallbackRoute: AppRoutes.account,
    maxWidth: 480,
    cardOnWide: true,
    aside: BlocBuilder<EditProfileCubit, EditProfileState>(
      builder: (context, state) => Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
        decoration: BoxDecoration(
          color: context.jotterColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.jotterColors.line),
        ),
        child: _photo(context, state, context.watch<MeCubit>().state),
      ),
    ),
    child: BlocConsumer<EditProfileCubit, EditProfileState>(
      listener: _applyUpdate,
      builder: (context, state) {
        final me = context.watch<MeCubit>().state;
        final wide = context.isExpanded;
        return Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!wide) ...[
                const SizedBox(height: 16),
                _photo(context, state, me),
                const SizedBox(height: 28),
              ] else ...[
                Text(
                  'Your details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 18),
              ],
              if (state.busy) const LinearProgressIndicator(minHeight: 2),
              if (state.error != null) MessageStrip(state.error!, error: true),
              if (state.notice != null)
                MessageStrip(state.notice!, tone: JotterTone.success),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('profile-name'),
                controller: _name,
                enabled: !state.busy,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: (value) =>
                    validateRequired(value, 'your display name'),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: state.busy ? null : (_) => _saveName(),
              ),
              const SizedBox(height: 8),
              _EmailRow(me: me),
              const SizedBox(height: 24),
              Align(
                alignment: wide ? Alignment.centerRight : Alignment.center,
                child: SizedBox(
                  width: wide ? null : double.infinity,
                  child: FilledButton(
                    key: const Key('save-profile'),
                    onPressed: state.busy ? null : _saveName,
                    child: const Text('Save name'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

enum _PhotoChoice { gallery, camera, remove }

class _EmailRow extends StatelessWidget {
  const _EmailRow({required this.me});

  final MeState me;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: const InputDecoration(labelText: 'Email'),
    child: Row(
      children: [
        Expanded(child: Text(me.account.email)),
        Icon(
          me.account.isActivated
              ? Icons.verified_outlined
              : Icons.error_outline_rounded,
          size: 16,
          color: me.account.isActivated
              ? context.jotterColors.muted
              : JotterColors.accent,
        ),
        const SizedBox(width: 6),
        Text(
          me.account.isActivated ? 'Confirmed' : 'Not confirmed',
          style: TextStyle(fontSize: 12.5, color: context.jotterColors.muted),
        ),
      ],
    ),
  );
}
