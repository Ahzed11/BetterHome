import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

late String _household;

/// A household with a done manual chore ("Vacuum") and a done recurrence-like chore ("Dishes", due
/// tomorrow, so a reversion reopens it).
Future<AppSession> _session() async {
  final session = AppSession(repository: FakeHouseholdsRepository());
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  _household = (await session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  )).id;
  final tasks = session.tasksRepository;
  final vacuum = await tasks.createTemplate(
    householdId: _household,
    title: 'Vacuum',
    points: 5,
    latePoints: 2,
  );
  final dishes = await tasks.createTemplate(
    householdId: _household,
    title: 'Dishes',
    points: 3,
    latePoints: 1,
  );
  final manual = await tasks.quickLog(
    householdId: _household,
    templateId: vacuum.id,
  );
  await tasks.revert(_household, manual.id, reason: 'Not clean');
  final open = await tasks.createOpen(
    householdId: _household,
    templateId: dishes.id,
  );
  await tasks.complete(_household, open.id);
  await tasks.revert(_household, open.id, reason: 'Plates still dirty');
  return session;
}

Future<void> _pump(
  WidgetTester tester,
  AppSession session, {
  Locale locale = const Locale('en'),
}) => pumpScreen(
  tester,
  home: ChoresScreen(session: session, householdId: _household),
  locale: locale,
);

void main() {
  testWidgets('a reverted chore shows the reason the admin gave', (
    tester,
  ) async {
    await _pump(tester, await _session());

    expect(find.text('Reverted: Not clean'), findsOneWidget);
    expect(find.text('reverted · 5 pts'), findsOneWidget);
  });

  testWidgets('a chore that was reopened shows the reason too', (tester) async {
    await _pump(tester, await _session());

    expect(find.text('Reverted: Plates still dirty'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('a chore done again no longer shows the old reason', (
    tester,
  ) async {
    final session = await _session();
    final tasks = session.tasksRepository;
    final reopened = (await tasks.listTasks(
      _household,
    )).firstWhere((t) => t.status == TaskStatus.open);
    await tasks.complete(_household, reopened.id);

    await _pump(tester, session);

    expect(find.text('Reverted: Plates still dirty'), findsNothing);
    expect(find.text('Reverted: Not clean'), findsOneWidget);
  });

  testWidgets('a chore never reverted shows no reason line', (tester) async {
    final session = await _session();
    final tasks = session.tasksRepository;
    final template = (await tasks.listTemplates(_household)).first;
    await tasks.quickLog(householdId: _household, templateId: template.id);

    await _pump(tester, session);

    expect(find.textContaining('Reverted:'), findsNWidgets(2));
  });

  testWidgets('the reason line is in French in French', (tester) async {
    await _pump(tester, await _session(), locale: const Locale('fr'));

    expect(find.text('Annulée : Not clean'), findsOneWidget);
  });
}
