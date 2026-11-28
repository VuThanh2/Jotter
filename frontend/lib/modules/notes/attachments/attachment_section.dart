import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/modules/notes/attachments/attachment_source_sheet.dart';
import 'package:jotter/modules/notes/attachments/attachments_cubit.dart';
import 'package:jotter/modules/notes/attachments/attachments_state.dart';
import 'package:jotter/shared/lib/file_service.dart';
import 'package:jotter/shared/widgets/confirm_dialog.dart';
import 'package:jotter/shared/widgets/state_views.dart';

/// Attachment list shown under the note body. Expects an [AttachmentsCubit].
class AttachmentSection extends StatelessWidget {
  const AttachmentSection({super.key, required this.canEdit});

  final bool canEdit;

  static Future<void> addFiles(BuildContext context) async {
    final cubit = context.read<AttachmentsCubit>();
    final source = cubit.supportsCamera
        ? await showAttachmentSourceSheet(
            context,
            supportsCamera: cubit.supportsCamera,
            supportsGallery: cubit.supportsGallery,
          )
        : PickSource.files;
    if (source != null) await cubit.pickAndUpload(source);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AttachmentsCubit, AttachmentsState>(
    builder: (context, state) {
      final cubit = context.read<AttachmentsCubit>();
      if (state.files.isEmpty && state.uploads.isEmpty && !canEdit) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                size: 18,
                color: context.jotterColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                'Attachments',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (state.files.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '${state.files.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.jotterColors.muted,
                  ),
                ),
              ],
              const Spacer(),
              if (canEdit)
                TextButton.icon(
                  key: const Key('add-attachment'),
                  onPressed: state.uploading ? null : () => addFiles(context),
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: const Text('Add files'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.error != null) ...[
            MessageStrip(state.error!, error: true),
            const SizedBox(height: 10),
          ],
          for (final upload in state.uploads)
            _UploadRow(
              item: upload,
              onDismiss: () => cubit.dismissUpload(upload),
            ),
          if (state.loading && state.files.isEmpty)
            const LinearProgressIndicator(minHeight: 2)
          else if (state.files.isEmpty && state.uploads.isEmpty)
            _DropHint(
              onTap: canEdit && !state.uploading
                  ? () => addFiles(context)
                  : null,
            ),
          for (final file in state.files)
            _FileRow(
              file: file,
              onOpen: () => context.push(
                AppRoutes.attachment(cubit.noteId, file.id),
                extra: file,
              ),
              onRemove: canEdit
                  ? () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Remove attachment?',
                        message:
                            '“${file.name}” will be removed from this note.',
                        confirmLabel: 'Remove',
                        icon: Icons.link_off_rounded,
                      );
                      if (confirmed) await cubit.remove(file.id);
                    }
                  : null,
            ),
        ],
      );
    },
  );
}

/// The empty state: a dashed-looking box inviting the first file.
class _DropHint extends StatelessWidget {
  const _DropHint({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Material(
      color: palette.sidebar.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line, width: 1.2),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, color: palette.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Images, videos, PDFs and other documents up to 25 MB each.',
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A file type's icon on a soft tile in a colour of its own.
class _FileBadge extends StatelessWidget {
  const _FileBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: context.jotterColors.tint(color),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(
      icon,
      size: 20,
      color: context.jotterColors.ink.withValues(alpha: .75),
    ),
  );
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onOpen, this.onRemove});

  final NoteAttachment file;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  (IconData, Color) get _look => file.isImage
      ? (Icons.image_outlined, JotterColors.sage)
      : file.isVideo
      ? (Icons.movie_outlined, JotterColors.lavender)
      : file.mimeType == 'application/pdf'
      ? (Icons.picture_as_pdf_outlined, JotterColors.peach)
      : (Icons.insert_drive_file_outlined, JotterColors.butter);

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final (icon, color) = _look;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
          leading: _FileBadge(icon: icon, color: color),
          title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(file.sizeLabel),
          onTap: onOpen,
          trailing: onRemove == null
              ? Icon(Icons.chevron_right_rounded, color: palette.muted)
              : IconButton(
                  tooltip: 'Remove ${file.name}',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
        ),
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.item, required this.onDismiss});

  final UploadItem item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final failed = item.status == UploadStatus.failed;
    final palette = context.jotterColors;
    final error = palette.tone(JotterTone.error);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: EntranceTransition(
        duration: JotterMotion.medium,
        child: Container(
          decoration: BoxDecoration(
            color: failed ? error.background : palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: failed ? error.border : palette.line),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
                leading: failed
                    ? _FileBadge(
                        icon: Icons.error_outline_rounded,
                        color: JotterColors.peach,
                      )
                    : const SizedBox.square(
                        dimension: 40,
                        child: Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  failed ? item.error ?? 'Upload failed.' : 'Uploading…',
                  style: failed ? TextStyle(color: error.foreground) : null,
                ),
                trailing: failed
                    ? IconButton(
                        tooltip: 'Dismiss',
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      )
                    : null,
              ),
              if (!failed)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
