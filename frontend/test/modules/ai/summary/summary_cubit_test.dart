import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/modules/ai/summary/summary_api.dart';
import 'package:jotter/modules/ai/summary/summary_cubit.dart';
import 'package:jotter/modules/ai/summary/summary_state.dart';

import '../../../helpers/fake_api.dart';

class _FakeSummaryApi extends SummaryApi {
  _FakeSummaryApi({this.savedSummary})
    : super(fakeApi((_) async => jsonResponse({})));

  final NoteSummary? savedSummary;
  final events = StreamController<SummaryEvent>();

  @override
  Future<NoteSummary?> saved(String noteId) async => savedSummary;

  @override
  Stream<SummaryEvent> generate(String noteId) => events.stream;
}

void main() {
  test('loads the saved summary', () async {
    final saved = NoteSummary('Main points.', DateTime(2026));
    final cubit = SummaryCubit(
      _FakeSummaryApi(savedSummary: saved),
      noteId: 'n',
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.text, 'Main points.');
    expect(cubit.state.savedAt, DateTime(2026));
    expect(cubit.state.status, SummaryStatus.ready);
  });

  test('streams text, then keeps the completed summary as saved', () async {
    final api = _FakeSummaryApi();
    final cubit = SummaryCubit(api, noteId: 'n');
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.generate();
    api.events.add(const SummaryEvent(kind: 'delta', text: 'Budget '));
    await pumpEventQueue();
    expect(cubit.state.text, 'Budget ');
    expect(cubit.state.generating, isTrue);

    api.events.add(
      SummaryEvent(
        kind: 'completed',
        text: 'Budget for March.',
        generatedAt: DateTime(2026, 3),
      ),
    );
    await api.events.close();
    await pumpEventQueue();
    expect(cubit.state.text, 'Budget for March.');
    expect(cubit.state.savedAt, DateTime(2026, 3));
    expect(cubit.state.generating, isFalse);
  });

  test('stopping keeps the partial text but marks it unsaved', () async {
    final api = _FakeSummaryApi();
    final cubit = SummaryCubit(api, noteId: 'n');
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.generate();
    api.events.add(const SummaryEvent(kind: 'delta', text: 'Half'));
    await pumpEventQueue();
    await cubit.stop();
    expect(cubit.state.text, 'Half');
    expect(cubit.state.isPartial, isTrue);
  });

  test('a failed stream reports why and stops generating', () async {
    final api = _FakeSummaryApi();
    final cubit = SummaryCubit(api, noteId: 'n');
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.generate();
    api.events.add(
      const SummaryEvent(kind: 'failed', message: 'The AI service is busy.'),
    );
    await pumpEventQueue();
    expect(cubit.state.error, 'The AI service is busy.');
    expect(cubit.state.generating, isFalse);
  });
}
