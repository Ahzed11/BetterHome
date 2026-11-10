import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

final DateTime _now = DateTime.utc(2026, 10, 14, 9);

void main() {
  testWidgets('a dismissed chore is not listed and not counted', (
    tester,
  ) async {
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
    await tasks.createOpen(
      householdId: household.id,
      templateId: template.id,
      dueAt: _now.add(const Duration(hours: 1)),
    );
    final dismissed = await tasks.createOpen(
      householdId: household.id,
      templateId: template.id,
      dueAt: _now.add(const Duration(hours: 2)),
    );
    await tasks.dismiss(household.id, dismissed.id);

    await pumpScreen(
      tester,
      home: ChoresScreen(
        session: session,
        householdId: household.id,
        now: () => _now,
      ),
    );

    expect(find.text('Vacuum'), findsOneWidget);
    expect(find.textContaining('Dismissed'), findsNothing);
    expect(find.text('All · 1'), findsOneWidget);
  });
}
