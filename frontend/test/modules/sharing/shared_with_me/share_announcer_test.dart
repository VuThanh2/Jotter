import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_announcer.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_cubit.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_state.dart';

class _Inbox extends Cubit<ShareInboxState> implements ShareInboxCubit {
  _Inbox() : super(const ShareInboxState());

  void announce(ShareAnnouncement announcement) =>
      emit(ShareInboxState(unviewed: 1, latest: announcement));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a new share is announced and Open goes to the note', (
    tester,
  ) async {
    final inbox = _Inbox();
    addTearDown(inbox.close);
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ShareInboxCubit>.value(
          value: inbox,
          child: ShareAnnouncer(
            onOpenNote: opened.add,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );

    inbox.announce(
      const ShareAnnouncement(
        noteId: 'note-9',
        title: 'Recipes',
        sharedBy: 'Owner',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Owner shared “Recipes” with you.'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened, ['note-9']);
  });
}
