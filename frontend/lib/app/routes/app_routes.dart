abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static const notes = '/notes';
  static const sharedWithMe = '/shared-with-me';
  static const ask = '/ask';
  static const labels = '/labels';

  static const account = '/account';
  static const profile = '/account/profile';
  static const preferences = '/account/preferences';
  static const password = '/account/password';
  static const activation = '/account/activation';

  static const publicPaths = {login, register, forgotPassword};

  static String note(String id) => '$notes/$id';

  /// A client-generated id; the note is created on its first autosave.
  static String newNote(String id, {List<String> labelIds = const []}) =>
      Uri(
        path: note(id),
        queryParameters: {
          'new': '1',
          if (labelIds.isNotEmpty) 'labels': labelIds.join(','),
        },
      ).toString();

  static String attachment(String noteId, String attachmentId) =>
      '${note(noteId)}/attachments/$attachmentId';
}
