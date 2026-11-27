import 'dart:convert';
import 'dart:typed_data';

import '../models/note_features.dart';
import 'api_note_repository.dart';
import 'note_repository.dart';

const maxAttachmentBytes = 25 * 1024 * 1024;

void validateAttachment(Uint8List bytes, String filename) {
  if (filename.trim().isEmpty || filename.length > 255) {
    throw const RepositoryException(
      'Use a file name between 1 and 255 characters.',
    );
  }
  if (bytes.isEmpty) {
    throw const RepositoryException('Empty files cannot be attached.');
  }
  if (bytes.length > maxAttachmentBytes) {
    throw const RepositoryException(
      'Each attachment must be 25 MB or smaller.',
    );
  }
  const signatures = [
    [0x4d, 0x5a],
    [0x7f, 0x45, 0x4c, 0x46],
    [0xfe, 0xed, 0xfa, 0xce],
    [0xfe, 0xed, 0xfa, 0xcf],
    [0xce, 0xfa, 0xed, 0xfe],
    [0xcf, 0xfa, 0xed, 0xfe],
    [0xca, 0xfe, 0xba, 0xbe],
  ];
  if (signatures.any(
    (signature) =>
        bytes.length >= signature.length &&
        List.generate(
          signature.length,
          (index) => bytes[index] == signature[index],
        ).every((value) => value),
  )) {
    throw const RepositoryException('Executable files cannot be attached.');
  }
}

extension NoteFeaturesApi on ApiNoteRepository {
  Future<List<NoteAttachment>> listAttachments(String noteId) async {
    final json = await request('GET', '/api/notes/$noteId/attachments');
    return (json['items'] as List)
        .map((item) => NoteAttachment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> attachFile(
    String noteId,
    Uint8List bytes,
    String filename,
  ) async {
    validateAttachment(bytes, filename);
    await upload(
      '/api/notes/$noteId/attachments',
      bytes,
      filename,
      field: 'files',
    );
  }

  Future<void> removeAttachment(String id) async {
    await request('DELETE', '/api/attachments/$id', idempotent: true);
  }

  Future<Uint8List> attachmentBytes(String id) =>
      download('/api/attachments/$id/content');

  Future<List<NoteShare>> listShares(String noteId) async {
    final json = await request('GET', '/api/notes/$noteId/shares');
    return (json['items'] as List)
        .map((item) => NoteShare.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ShareInvitationResult> inviteToNote(
    String noteId,
    List<String> emails,
    String permission,
  ) => inviteRecipients(
    noteId,
    emails.map((email) => (email: email, permission: permission)).toList(),
  );

  Future<ShareInvitationResult> inviteRecipients(
    String noteId,
    List<({String email, String permission})> invitations,
  ) async {
    final recipients = <String, ({String email, String permission})>{};
    for (final invitation in invitations) {
      _validatePermission(invitation.permission);
      final email = invitation.email.trim();
      if (email.isNotEmpty) {
        recipients[email.toLowerCase()] = (
          email: email,
          permission: invitation.permission,
        );
      }
    }
    if (recipients.isEmpty || recipients.length > 20) {
      throw const RepositoryException(
        'Invite between 1 and 20 registered email addresses at a time.',
      );
    }
    final Map<String, dynamic> json;
    try {
      json = await request(
        'POST',
        '/api/notes/$noteId/shares',
        body: {
          'recipients': recipients.values
              .map(
                (item) => {'email': item.email, 'permission': item.permission},
              )
              .toList(),
        },
        idempotent: true,
      );
    } on RepositoryException catch (error) {
      // When nobody could be invited the server still says why for each one.
      if (error.details['rejected'] is! List) rethrow;
      return ShareInvitationResult(0, _rejected(error.details));
    }
    return ShareInvitationResult(
      (json['created'] as List).length,
      _rejected(json),
    );
  }

  static List<({String email, String code})> _rejected(
    Map<String, dynamic> json,
  ) => [
    for (final item in json['rejected'] as List)
      (email: item['email'] as String, code: item['code'] as String),
  ];

  Future<void> changeSharePermission(
    String noteId,
    String shareId,
    String permission,
  ) async {
    _validatePermission(permission);
    await request(
      'PUT',
      '/api/notes/$noteId/shares/$shareId',
      body: {'permission': permission},
      idempotent: true,
    );
  }

  Future<void> revokeShare(String noteId, String shareId) async {
    await request(
      'DELETE',
      '/api/notes/$noteId/shares/$shareId',
      idempotent: true,
    );
  }

  Future<void> enableProtection(
    String noteId,
    String password,
    String confirmation,
  ) async {
    _validatePassword(password, confirmation);
    await request(
      'POST',
      '/api/notes/$noteId/protection',
      body: {'password': password, 'confirmPassword': confirmation},
      idempotent: true,
    );
  }

  Future<void> changeNotePassword(
    String noteId,
    String current,
    String password,
    String confirmation,
  ) async {
    _validatePassword(password, confirmation);
    await request(
      'PUT',
      '/api/notes/$noteId/protection/password',
      body: {
        'currentPassword': current,
        'newPassword': password,
        'confirmPassword': confirmation,
      },
      idempotent: true,
    );
  }

  Future<void> disableProtection(String noteId, String password) async {
    await request(
      'POST',
      '/api/notes/$noteId/protection/disable',
      body: {'currentPassword': password},
      idempotent: true,
    );
  }

  Future<void> relockNote(String noteId) async {
    await request('DELETE', '/api/notes/$noteId/unlock');
  }

  Future<NoteSummary?> getSummary(String noteId) async {
    try {
      return NoteSummary.fromJson(
        await request('GET', '/api/notes/$noteId/summary'),
      );
    } on RepositoryException catch (error) {
      if (error.code == 'SummaryNotFound') return null;
      rethrow;
    }
  }

  Stream<SummaryEvent> generateSummary(String noteId) =>
      decodeSummaryEvents(stream('POST', '/api/notes/$noteId/summary'));

  Future<NotesAnswer> askNotes(String question) async {
    if (question.trim().isEmpty || question.length > 1000) {
      throw const RepositoryException(
        'Ask a question between 1 and 1,000 characters.',
      );
    }
    return NotesAnswer.fromJson(
      await request('POST', '/api/ai/ask', body: {'question': question.trim()}),
    );
  }
}

void _validatePermission(String permission) {
  if (!const ['ReadOnly', 'Edit'].contains(permission)) {
    throw const RepositoryException('Choose view-only or editing access.');
  }
}

void _validatePassword(String password, String confirmation) {
  if (password.length < 4 || password.length > 128) {
    throw const RepositoryException(
      'A note password must contain 4–128 characters.',
    );
  }
  if (password != confirmation) {
    throw const RepositoryException('The passwords do not match.');
  }
}

/// Decodes SSE across arbitrary HTTP chunk boundaries, including split CRLFs.
Stream<SummaryEvent> decodeSummaryEvents(Stream<String> source) async* {
  var event = 'message';
  final data = <String>[];
  var completed = false;
  await for (final line in source.transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        final json = jsonDecode(data.join('\n')) as Map<String, dynamic>;
        switch (event) {
          case 'delta':
            yield SummaryEvent(kind: event, text: json['delta'] as String);
          case 'completed':
            completed = true;
            yield SummaryEvent(
              kind: event,
              text: json['summaryText'] as String,
              generatedAt: DateTime.parse(json['generatedAt'] as String),
            );
          case 'failed':
            yield SummaryEvent(
              kind: event,
              code: json['code'] as String?,
              message:
                  json['message'] as String? ??
                  'Summary generation failed. Please try again.',
            );
            return;
        }
        if (completed) return;
      }
      event = 'message';
      data.clear();
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }
  if (!completed) {
    throw const RepositoryException(
      'The summary stream ended early. Please try again.',
    );
  }
}
