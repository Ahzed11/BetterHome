import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/new_recurring_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

Future<(AppSession, String)> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final session = AppSession(repository: FakeHouseholdsRepository());
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  final household = await session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  );
  await pumpScreen(
    tester,
    home: NewRecurringScreen(session: session, householdId: household.id),
    locale: locale,
    textScale: textScale,
  );
  return (session, household.id);
}

Future<TaskRecurrence> _saved(AppSession session, String householdId) async {
  final template = (await session.tasksRepository.listTemplates(
    householdId,
  )).single;
  final recurrence = await session.tasksRepository.getRecurrence(
    householdId,
    template.id,
  );
  return recurrence!;
}

Future<Finder> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  return finder;
}

void main() {
  testWidgets('saving is not possible without a name', (tester) async {
    await _pump(tester);

    final save = await _scrollTo(
      tester,
      find.widgetWithText(FilledButton, 'Save chore'),
    );

    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('a name makes saving possible', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Bins');
    final save = await _scrollTo(
      tester,
      find.widgetWithText(FilledButton, 'Save chore'),
    );

    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets('saves a chore and a weekly rotation', (tester) async {
    final (session, householdId) = await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Bins');
    await tester.tap(
      await _scrollTo(tester, find.byTooltip('Increase interval')),
    );
    await tester.pump();
    await tester.tap(
      await _scrollTo(tester, find.widgetWithText(FilledButton, 'Save chore')),
    );
    await tester.pumpAndSettle();

    final template = (await session.tasksRepository.listTemplates(
      householdId,
    )).single;
    expect(template.title, 'Bins');
    expect(template.points, 10);
    expect(template.latePoints, 5);
    final recurrence = await _saved(session, householdId);
    expect(recurrence.rrule, startsWith('FREQ=WEEKLY;INTERVAL=2;BYDAY='));
    expect(recurrence.assignmentMode, AssignmentMode.roundRobin);
  });

  testWidgets('late points never go above on-time points', (tester) async {
    await _pump(tester);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('Fewer On time'));
      await tester.pump();
    }

    expect(find.text('4'), findsNWidgets(2));
    final more = find.ancestor(
      of: find.byTooltip('More If late, still'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(more).onPressed, isNull);
  });

  testWidgets('daily and monthly rules', (tester) async {
    final (session, householdId) = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Plants');

    await tester.tap(await _scrollTo(tester, find.text('Monthly')));
    await tester.pump();
    await tester.tap(
      await _scrollTo(tester, find.widgetWithText(FilledButton, 'Save chore')),
    );
    await tester.pumpAndSettle();

    expect(
      (await _saved(session, householdId)).rrule,
      'FREQ=MONTHLY;BYMONTHDAY=1',
    );
  });

  testWidgets('one person needs someone picked and is saved as fixed', (
    tester,
  ) async {
    final (session, householdId) = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Bins');
    await tester.tap(await _scrollTo(tester, find.text('One person')));
    await tester.pumpAndSettle();

    final save = await _scrollTo(
      tester,
      find.widgetWithText(FilledButton, 'Save chore'),
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.text('You'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final recurrence = await _saved(session, householdId);
    expect(recurrence.assignmentMode, AssignmentMode.fixed);
    expect(recurrence.fixedAssigneeId, session.profile?.id);
  });

  testWidgets('the screen is in French in French at 200% text size', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('fr'), textScale: 2);

    expect(find.text('Nouvelle tâche récurrente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
