import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/modules/notes/attachments/attachment_viewer_page.dart';
import 'package:jotter/modules/profile/shared/me_api.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';

import '../../../helpers/fake_api.dart';

void main() {
  testWidgets('Escape closes the viewer like the back button', (tester) async {
    final api = fakeApi((_) async => jsonResponse({'code': 'NotFound'}, 404));
    final me = MeCubit(MeApi(api), onAccountChanged: () {});
    addTearDown(me.close);
    final router = GoRouter(
      initialLocation: '/notes/n',
      routes: [
        GoRoute(
          path: '/notes/:id',
          builder: (_, _) => const Text('Editor open'),
          routes: [
            GoRoute(
              path: 'attachments/:attachmentId',
              builder: (_, state) => AttachmentViewerPage(
                noteId: 'n',
                attachmentId: state.pathParameters['attachmentId']!,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<ApiNoteRepository>.value(
        value: api,
        child: BlocProvider.value(
          value: me,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    router.push('/notes/n/attachments/a');
    await tester.pumpAndSettle();
    expect(find.text('Editor open'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Editor open'), findsOneWidget);
  });
}
