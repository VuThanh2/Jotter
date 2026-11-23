import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/layouts/app_shell.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/startup_page.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/modules/ai/ask_ai/ask_ai_page.dart';
import 'package:jotter/modules/authentication/activation/activation_page.dart';
import 'package:jotter/modules/authentication/change_password/change_password_page.dart';
import 'package:jotter/modules/authentication/forgot_password/forgot_password_page.dart';
import 'package:jotter/modules/authentication/login/login_page.dart';
import 'package:jotter/modules/authentication/register/register_page.dart';
import 'package:jotter/modules/labels/label_management/label_management_page.dart';
import 'package:jotter/modules/notes/attachments/attachment_viewer_page.dart';
import 'package:jotter/modules/notes/note_editor/note_editor_page.dart';
import 'package:jotter/modules/notes/notes_home/notes_home_page.dart';
import 'package:jotter/modules/profile/account/account_page.dart';
import 'package:jotter/modules/profile/edit_profile/edit_profile_page.dart';
import 'package:jotter/modules/profile/preferences/preferences_page.dart';
import 'package:jotter/modules/sharing/shared_with_me/shared_with_me_page.dart';
import 'package:jotter/shared/lib/session.dart';

GoRouter createAppRouter(SessionCubit session) => GoRouter(
  initialLocation: AppRoutes.notes,
  refreshListenable: _StreamListenable(session.stream),
  redirect: (context, state) => _guard(session.state, state),
  routes: [
    GoRoute(path: '/', redirect: (_, _) => AppRoutes.notes),
    GoRoute(
      path: AppRoutes.startup,
      builder: (_, _) => const StartupPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (_, state) => LoginPage(
        passwordReset: state.uri.queryParameters['reset'] == '1',
      ),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (_, _) => const RegisterPage(),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (_, _) => const ForgotPasswordPage(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.notes,
              builder: (_, _) => const NotesHomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.sharedWithMe,
              builder: (_, _) => const SharedWithMePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.ask,
              builder: (_, _) => const AskAiPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '${AppRoutes.notes}/:noteId',
      builder: (_, state) => NoteEditorPage(
        noteId: state.pathParameters['noteId']!,
        isNew: state.uri.queryParameters['new'] == '1',
        initialLabelIds: _split(state.uri.queryParameters['labels']),
      ),
      routes: [
        GoRoute(
          path: 'attachments/:attachmentId',
          builder: (_, state) => AttachmentViewerPage(
            noteId: state.pathParameters['noteId']!,
            attachmentId: state.pathParameters['attachmentId']!,
            file: state.extra is NoteAttachment
                ? state.extra! as NoteAttachment
                : null,
          ),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.labels,
      builder: (_, _) => const LabelManagementPage(),
    ),
    GoRoute(
      path: AppRoutes.account,
      builder: (_, _) => const AccountPage(),
      routes: [
        GoRoute(
          path: 'profile',
          builder: (_, _) => const EditProfilePage(),
        ),
        GoRoute(
          path: 'preferences',
          builder: (_, _) => const PreferencesPage(),
        ),
        GoRoute(
          path: 'password',
          builder: (_, _) => const ChangePasswordPage(),
        ),
        GoRoute(
          path: 'activation',
          builder: (_, _) => const ActivationPage(),
        ),
      ],
    ),
  ],
);

String? _guard(SessionState session, GoRouterState state) {
  final path = state.matchedLocation;
  final from = state.uri.queryParameters['from'];
  final isPublic = AppRoutes.publicPaths.contains(path);
  switch (session) {
    case SessionRestoring():
      if (path == AppRoutes.startup) return null;
      return _withFrom(AppRoutes.startup, state.uri.toString());
    case SessionSignedOut(:final resumeLocation):
      if (isPublic) return null;
      final target = path == AppRoutes.startup ? from : state.uri.toString();
      return resumeLocation && _isSafeTarget(target) && target != AppRoutes.notes
          ? _withFrom(AppRoutes.login, target!)
          : AppRoutes.login;
    case SessionActive():
      if (!isPublic && path != AppRoutes.startup) return null;
      return _isSafeTarget(from) ? from : AppRoutes.notes;
  }
}

String _withFrom(String path, String from) =>
    Uri(path: path, queryParameters: {'from': from}).toString();

bool _isSafeTarget(String? target) {
  if (target == null || !target.startsWith('/') || target.startsWith('//')) {
    return false;
  }
  final path = Uri.parse(target).path;
  return path != AppRoutes.startup && !AppRoutes.publicPaths.contains(path);
}

List<String> _split(String? value) =>
    value?.split(',').where((id) => id.isNotEmpty).toList() ?? const [];

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
