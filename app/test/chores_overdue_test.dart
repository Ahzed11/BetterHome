import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/widgets/overdue_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

final DateTime _due = DateTime.utc(2026, 10, 14, 9);

/// A household with one chore due at [_due] whose template is worth 5 points, or 2 once late.
Future<AppSession> _session({bool complete = false}) async {
  final session = AppSession(repository: FakeHouseholdsRepository());
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  final household = await session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  );
  final tasks = session.tasksRepository;
  final template = await tasks.createTemplate(
    householdId: household.id,
    title: 'Vacuum',
    points: 5,
    latePoints: 2,
  );
  final open = await tasks.createOpen(
    householdId: household.id,
    templateId: template.id,
    dueAt: _due,
  );
  if (complete) {
    await tasks.complete(household.id, open.id);
  }
  return session;
}

Future<void> _pump(
  WidgetTester tester,
  AppSession session, {
  required DateTime now,
  Locale locale = const Locale('en'),
}) async {
  final household = (await session.repository.listHouseholds()).single;
  await pumpScreen(
    tester,
    home: ChoresScreen(
      session: session,
      householdId: household.id,
      now: () => now,
    ),
    locale: locale,
  );
}

void main() {
  testWidgets('a chore past its due date says what is still possible', (
    tester,
  ) async {
    await _pump(
      tester,
      await _session(),
      now: _due.add(const Duration(minutes: 1)),
    );

    expect(find.text('Overdue · still +2'), findsOneWidget);
    expect(find.textContaining('open ·'), findsNothing);
  });

  testWidgets('the overdue label is soft coral, never red', (tester) async {
    await _pump(
      tester,
      await _session(),
      now: _due.add(const Duration(hours: 3)),
    );

    final badge = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(OverdueBadge),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final shape = badge.decoration as ShapeDecoration;

    expect(shape.color, AppTokens.overdueTint);
    expect(AppTokens.overdue, isNot(const Color(0xFFFF0000)));
  });

  testWidgets('a chore that is not yet due shows its points as before', (
    tester,
  ) async {
    await _pump(
      tester,
      await _session(),
      now: _due.subtract(const Duration(minutes: 1)),
    );

    expect(find.text('open · 5 pts'), findsOneWidget);
    expect(find.byType(OverdueBadge), findsNothing);
  });

  testWidgets('a chore exactly at its due date is not overdue yet', (
    tester,
  ) async {
    await _pump(tester, await _session(), now: _due);

    expect(find.byType(OverdueBadge), findsNothing);
  });

  testWidgets('a chore done after its due date is not shown as overdue', (
    tester,
  ) async {
    await _pump(
      tester,
      await _session(complete: true),
      now: _due.add(const Duration(days: 1)),
    );

    expect(find.byType(OverdueBadge), findsNothing);
  });

  testWidgets('the label is in French in French', (tester) async {
    await _pump(
      tester,
      await _session(),
      now: _due.add(const Duration(minutes: 1)),
      locale: const Locale('fr'),
    );

    expect(find.text('En retard · encore +2'), findsOneWidget);
  });
}
