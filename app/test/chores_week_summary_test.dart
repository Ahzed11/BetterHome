import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'support/screen_harness.dart';

Future<AppSession> _session({required bool withOpenChore}) async {
  final session = AppSession(repository: FakeHouseholdsRepository());
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  final household = await session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  );
  if (withOpenChore) {
    final tasks = session.tasksRepository;
    final template = await tasks.createTemplate(
      householdId: household.id,
      title: 'Vacuum',
      points: 5,
      latePoints: 2,
    );
    await tasks.createOpen(householdId: household.id, templateId: template.id);
  }
  return session;
}

Future<void> _pump(
  WidgetTester tester,
  AppSession session, {
  Locale locale = const Locale('en'),
}) async {
  final household = (await session.repository.listHouseholds()).single;
  await pumpScreen(
    tester,
    home: ChoresScreen(session: session, householdId: household.id, mine: true),
    locale: locale,
  );
}

void main() {
  testWidgets('My chores greets the person and sums up the week', (
    tester,
  ) async {
    await _pump(tester, await _session(withOpenChore: true));

    expect(find.text('Hey Ada · Flat'), findsOneWidget);
    expect(find.text('Your chores'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('0 pts'), findsOneWidget);
    expect(
      find.text('5 pts within reach this week — one chore left.'),
      findsOneWidget,
    );
  });

  testWidgets('with nothing left the card says so', (tester) async {
    await _pump(tester, await _session(withOpenChore: false));

    expect(
      find.text('0 pts within reach this week — nothing left.'),
      findsOneWidget,
    );
  });

  testWidgets('the summary is in French in French', (tester) async {
    await _pump(
      tester,
      await _session(withOpenChore: true),
      locale: const Locale('fr'),
    );

    expect(find.text('Salut Ada · Flat'), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(
      find.text('5 pts à portée cette semaine — une tâche restante.'),
      findsOneWidget,
    );
  });
}
