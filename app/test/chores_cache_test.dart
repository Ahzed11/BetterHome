import 'dart:async';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:betterhome/ui/widgets/screen_skeletons.dart';
import 'package:betterhome/ui/widgets/week_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

final DateTime _due = DateTime.utc(2026, 10, 14, 9);
DateTime _now() => DateTime.utc(2026, 10, 14, 10);

/// Task answers that arrive when the test says so, as a network's would. Everything else is the
/// fake repository's own.
class _HeldTasks extends FakeTasksRepository {
  _HeldTasks() : super(now: _now);

  /// Every `listTasks` of the All chores tab, in order; the prefetch of My chores asks apart.
  final List<Completer<List<ChoreTask>>> asked = [];

  /// Every `listTasks` of My chores, in order.
  final List<Completer<List<ChoreTask>>> askedMine = [];

  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) {
    final held = Completer<List<ChoreTask>>();
    (mine ? askedMine : asked).add(held);
    return held.future;
  }

  /// Answers the [index]th question with what the fake holds now.
  Future<void> answer(int index, String householdId) async {
    asked[index].complete(await super.listTasks(householdId));
  }

  Future<void> answerMine(int index, String householdId) async {
    askedMine[index].complete(await super.listTasks(householdId, mine: true));
  }
}

class _World {
  _World(this.session, this.tasks, this.householdId, this.taskId);

  final AppSession session;
  final _HeldTasks tasks;
  final String householdId;
  final String taskId;
}

/// A household with one open chore, "Vacuum", whose task answers are held.
Future<_World> _world() async {
  SharedPreferences.setMockInitialValues({});
  final session = AppSession(
    repository: FakeHouseholdsRepository(),
    preferences: await SharedPreferences.getInstance(),
  );
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  final household = await session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  );
  final held = _HeldTasks();
  session.useTasksRepository(held);
  final template = await held.createTemplate(
    householdId: household.id,
    title: 'Vacuum',
    points: 5,
    latePoints: 2,
  );
  final task = await held.createOpen(
    householdId: household.id,
    templateId: template.id,
    dueAt: _due,
  );
  return _World(session, held, household.id, task.id);
}

Future<void> _pumpShell(WidgetTester tester, _World w) => pumpScreen(
  tester,
  home: HomeShell(session: w.session, now: _now),
  locale: const Locale('en'),
);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pumpAndSettle();
}

/// Opens the Chores tab again and draws exactly one frame, as the user sees it.
Future<void> _backToChores(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(NavigationDestination, 'All chores'));
  await tester.pump();
}

/// The chores tab once its first answer is in, after a visit to another tab.
Future<_World> _visited(WidgetTester tester) async {
  final w = await _world();
  await _pumpShell(tester, w);
  await w.tasks.answer(0, w.householdId);
  await tester.pumpAndSettle();
  await _openTab(tester, 'Lists');
  return w;
}

void main() {
  testWidgets('the first visit shows the skeleton until the answer arrives', (
    tester,
  ) async {
    final w = await _world();

    await _pumpShell(tester, w);
    expect(find.byType(ChoreListSkeleton), findsOneWidget);
    expect(find.textContaining('Vacuum'), findsNothing);

    await w.tasks.answer(0, w.householdId);
    await tester.pumpAndSettle();
    expect(find.byType(ChoreListSkeleton), findsNothing);
    expect(find.textContaining('Vacuum'), findsOneWidget);
  });

  testWidgets('coming back to the tab shows the data in the first frame', (
    tester,
  ) async {
    final w = await _visited(tester);

    await _backToChores(tester);

    expect(find.textContaining('Vacuum'), findsOneWidget);
    expect(find.byType(ChoreListSkeleton), findsNothing);
    // The refresh is on its way, held back: nothing is waiting for it on screen.
    expect(w.tasks.asked, hasLength(2));
  });

  testWidgets('what the refresh brings replaces the data, without loading', (
    tester,
  ) async {
    final w = await _visited(tester);
    await _backToChores(tester);
    await w.tasks.complete(
      w.householdId,
      w.taskId,
    ); // a housemate did it meanwhile

    await w.tasks.answer(1, w.householdId);
    await tester.pump();

    expect(find.byType(ChoreListSkeleton), findsNothing);
    expect(find.textContaining('Done · 5 pts'), findsOneWidget);
  });

  testWidgets('a refresh that fails keeps the data and shows no error', (
    tester,
  ) async {
    final w = await _visited(tester);
    await _backToChores(tester);

    w.tasks.asked[1].completeError(ApiException('down', statusCode: 503));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vacuum'), findsOneWidget);
    expect(find.text('Something went wrong'), findsNothing);
    expect(find.byType(ChoreListSkeleton), findsNothing);
  });

  testWidgets('a first visit that fails shows the error', (tester) async {
    final w = await _world();
    await _pumpShell(tester, w);

    w.tasks.asked[0].completeError(ApiException('down', statusCode: 503));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('Vacuum'), findsNothing);
  });

  testWidgets('completing a chore keeps the list on screen while it refreshes', (
    tester,
  ) async {
    final w = await _world();
    await _pumpShell(tester, w);
    await w.tasks.answer(0, w.householdId);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Complete'));
    await tester.pump();
    await tester.pump();

    // The request for the new list is held: the old one is still drawn, not a skeleton.
    expect(w.tasks.asked, hasLength(2));
    expect(find.byType(ChoreListSkeleton), findsNothing);
    expect(find.textContaining('Vacuum'), findsOneWidget);

    await w.tasks.answer(1, w.householdId);
    await tester.pumpAndSettle();
    expect(find.textContaining('Done · 5 pts'), findsOneWidget);
  });

  testWidgets('two requests for the same list at once are one request', (
    tester,
  ) async {
    final w = await _visited(tester);

    await _backToChores(tester);
    await _openTab(tester, 'Lists');
    await _backToChores(tester);

    // The first return asked, the second joined it while it was still held.
    expect(w.tasks.asked, hasLength(2));
  });

  testWidgets('another user does not see the data of the one before', (
    tester,
  ) async {
    final w = await _visited(tester);
    w.session.profile = const UserProfile(
      id: 'someone-else',
      authSubject: 'sub',
      email: 'bob@example.com',
      givenName: 'Bob',
      familyName: '',
      language: 'en',
      timezone: 'UTC',
    );

    await _backToChores(tester);

    expect(find.textContaining('Vacuum'), findsNothing);
    expect(find.byType(ChoreListSkeleton), findsOneWidget);
  });

  testWidgets('my chores keeps its week summary when it is opened again', (
    tester,
  ) async {
    final w = await _world();
    await _pumpShell(tester, w);
    await _openTab(tester, 'My chores');
    await w.tasks.answerMine(0, w.householdId);
    await tester.pumpAndSettle();
    expect(find.byType(WeekSummaryCard), findsOneWidget);
    await _openTab(tester, 'Lists');

    await tester.tap(find.widgetWithText(NavigationDestination, 'My chores'));
    await tester.pump();

    expect(find.byType(WeekSummaryCard), findsOneWidget);
    expect(find.byType(ChoreListSkeleton), findsNothing);
  });

  testWidgets('a screen of another household starts from nothing', (
    tester,
  ) async {
    final w = await _visited(tester);
    final other = await w.session.repository.createHousehold(
      name: 'Cabin',
      timezone: 'UTC',
    );

    await pumpScreen(
      tester,
      home: ChoresScreen(session: w.session, householdId: other.id, now: _now),
      locale: const Locale('en'),
    );

    expect(find.textContaining('Vacuum'), findsNothing);
    expect(find.byType(ChoreListSkeleton), findsOneWidget);
  });
}
