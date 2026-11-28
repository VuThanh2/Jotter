import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/profile/preferences/preferences_page.dart';
import 'package:jotter/modules/profile/preferences/preferences_store.dart';
import 'package:jotter/modules/profile/shared/me_api.dart';
import 'package:jotter/modules/profile/shared/me_cubit.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('preferences fit and remain usable at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final remote = ApiNoteRepository.fromSession(
        baseUrl: 'https://example.test',
        session: {
          'accessToken': 'test',
          'user': {
            'userId': '1',
            'email': 'a@example.test',
            'displayName': 'A',
            'isActivated': true,
          },
        },
      );
      final me = MeCubit(MeApi(remote), onAccountChanged: () {});
      final preferences = PreferencesCubit(PreferencesStore());
      addTearDown(() async {
        await me.close();
        await preferences.close();
        remote.dispose();
      });
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<MeCubit>.value(value: me),
            BlocProvider<PreferencesCubit>.value(value: preferences),
          ],
          child: const MaterialApp(home: PreferencesPage()),
        ),
      );
      await tester.pumpAndSettle();
      // Theme labels stay on one line instead of breaking mid-word.
      final label = tester.renderObject<RenderParagraph>(find.text('System'));
      expect(label.didExceedMaxLines, isFalse);
      expect(
        label
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 6),
            )
            .map((box) => box.top)
            .toSet(),
        hasLength(1),
      );
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(preferences.state.preferences.themeMode, 'Dark');
      await tester.scrollUntilVisible(
        find.textContaining('Saved on this device'),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved on this device'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
