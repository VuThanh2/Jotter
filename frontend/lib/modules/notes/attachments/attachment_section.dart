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
  Widget build(BuildContext context) =>
      BlocBuilder<AttachmentsCubit, AttachmentsState>(
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
                  Text(
                    'Attachments',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (canEdit)
                    TextButton.icon(
                      key: const Key('add-attachment'),
                      onPressed: state.uploading
                          ? null
                          : () => addFiles(context),
                      icon: const Icon(Icons.attach_file_rounded, size: 18),
                      label: const Text('Add files'),
                    ),
                ],
              ),
              if (state.error != null) ...[
                MessageStrip(state.error!, error: true),
                const SizedBox(height: 8),
              ],
              for (final upload in state.uploads)
                _UploadRow(
                  item: upload,
                  onDismiss: () => cubit.dismissUpload(upload),
                ),
              if (state.loading && state.files.isEmpty)
                const LinearProgressIndicator(minHeight: 2)
              else if (state.files.isEmpty && state.uploads.isEmpty)
                Text(
                  'Images, videos, PDFs and other documents up to 25 MB each.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.jotterColors.muted,
                  ),
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
                            message: '“${file.name}” will be removed from this note.',
                            confirmLabel: 'Remove',
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

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onOpen, this.onRemove});

  final NoteAttachment file;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  IconData get _icon => file.isImage
      ? Icons.image_outlined
      : file.isVideo
      ? Icons.movie_outlined
      : file.mimeType == 'application/pdf'
      ? Icons.picture_as_pdf_outlined
      : Icons.insert_drive_file_outlined;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(_icon),
    title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(file.sizeLabel),
    onTap: onOpen,
    trailing: onRemove == null
        ? null
        : IconButton(
            tooltip: 'Remove ${file.name}',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
  );
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.item, required this.onDismiss});

  final UploadItem item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final failed = item.status == UploadStatus.failed;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: failed
          ? Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            )
          : const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(failed ? item.error ?? 'Upload failed.' : 'Uploading…'),
      trailing: failed
          ? IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 20),
            )
          : null,
    );
  }
}
