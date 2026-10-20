import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

// A Wednesday.
final DateTime _now = DateTime(2026, 10, 14, 8);

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final session = AppSession(repository: FakeHouseholdsRepository());
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  final household = await session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  );
  final tasks = session.tasksRepository;
  final vacuum = await tasks.createTemplate(
    householdId: household.id,
    title: 'Vacuum',
    points: 5,
    latePoints: 2,
  );
  final bins = await tasks.createTemplate(
    householdId: household.id,
    title: 'Bins',
    points: 3,
    latePoints: 1,
  );
  await tasks.createOpen(
    householdId: household.id,
    templateId: vacuum.id,
    dueAt: DateTime(2026, 10, 14, 18),
  );
  await tasks.createOpen(
    householdId: household.id,
    templateId: bins.id,
    dueAt: DateTime(2026, 10, 16, 18),
  );
  await pumpScreen(
    tester,
    home: ChoresScreen(
      session: session,
      householdId: household.id,
      now: () => _now,
    ),
    locale: locale,
  );
}

void main() {
  testWidgets('the strip shows the week and counts the chores of each day', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Oct 12 – Oct 18'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Friday, October 16, 1 chore'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Saturday, October 17, no chores'),
      findsOneWidget,
    );
  });

  testWidgets('all chores show until a day is picked', (tester) async {
    await _pump(tester);

    expect(find.text('Vacuum'), findsOneWidget);
    expect(find.text('Bins'), findsOneWidget);
  });

  testWidgets('picking a day shows only its chores, picking it again undoes', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();
    expect(find.text('Bins'), findsOneWidget);
    expect(find.text('Vacuum'), findsNothing);

    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();
    expect(find.text('Vacuum'), findsOneWidget);
  });

  testWidgets('a day with nothing says so', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('17'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing on this day.'), findsOneWidget);
  });

  testWidgets('the strip is in French in French', (tester) async {
    await _pump(tester, locale: const Locale('fr'));

    expect(find.text('Auj.'), findsOneWidget);
    expect(find.text('12 oct. – 18 oct.'), findsOneWidget);
  });

  testWidgets('a quick-logged chore sits on the day it was done', (
    tester,
  ) async {
    final session = AppSession(repository: FakeHouseholdsRepository());
    await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
    final household = await session.repository.createHousehold(
      name: 'Flat',
      timezone: 'UTC',
    );
    final tasks = session.tasksRepository;
    final dishes = await tasks.createTemplate(
      householdId: household.id,
      title: 'Dishes',
      points: 4,
      latePoints: 1,
    );
    await tasks.quickLog(householdId: household.id, templateId: dishes.id);
    await pumpScreen(
      tester,
      home: ChoresScreen(session: session, householdId: household.id),
      locale: const Locale('en'),
    );

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Dishes'), findsOneWidget);

    final today = DateTime.now();
    final other = today.weekday == DateTime.sunday
        ? today.subtract(const Duration(days: 1))
        : today.add(const Duration(days: 1));
    await tester.tap(find.text('${other.day}'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing on this day.'), findsOneWidget);
  });
}
