import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:betterhome/ui/widgets/quick_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// A tasks repository whose quick-log is refused by the server.
class _QuickLogRefused extends FakeTasksRepository {
  @override
  Future<ChoreTask> quickLog({
    required String householdId,
    required String templateId,
  }) async => throw ApiException('refused', statusCode: 500);
}

late AppSession _session;
late String _household;

Future<void> _setUp({FakeTasksRepository? tasks}) async {
  _session = AppSession(repository: FakeHouseholdsRepository());
  await _session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  if (tasks != null) {
    _session.useTasksRepository(tasks);
  }
  _household = (await _session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  )).id;
  await _session.tasksRepository.createTemplate(
    householdId: _household,
    title: 'Dishes',
    points: 3,
    latePoints: 1,
  );
}

Future<void> _pump(WidgetTester tester, {Locale locale = const Locale('en')}) =>
    pumpScreen(
      tester,
      home: ChoresScreen(session: _session, householdId: _household),
      locale: locale,
    );

/// Taps the quick-log button and picks the only template.
Future<void> _quickLog(
  WidgetTester tester, {
  String label = 'I just did…',
}) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(QuickLogSheet),
      matching: find.text('Dishes'),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<List<ChoreTask>> _logged() =>
    _session.tasksRepository.listTasks(_household);

void main() {
  testWidgets('quick-logging waits five seconds before it logs', (
    tester,
  ) async {
    await _setUp();
    await _pump(tester);

    await _quickLog(tester);

    expect(find.text('Logging Dishes…'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(await _logged(), isEmpty);

    await tester.pump(const Duration(seconds: 4));
    expect(await _logged(), isEmpty, reason: 'still inside the window');

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final tasks = await _logged();
    expect(tasks.single.status, TaskStatus.done);
    expect(tasks.single.title, 'Dishes');
    expect(find.text('done · 3 pts'), findsOneWidget);
  });

  testWidgets('undoing within the window logs nothing at all', (tester) async {
    await _setUp();
    await _pump(tester);

    await _quickLog(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(await _logged(), isEmpty);
    expect(find.textContaining('done ·'), findsNothing);
  });

  testWidgets('switching tab inside the window still logs', (tester) async {
    await _setUp();
    await pumpScreen(
      tester,
      home: HomeShell(session: _session),
      locale: const Locale('en'),
    );

    await _quickLog(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Lists'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect((await _logged()).single.status, TaskStatus.done);
  });

  testWidgets('a refused log says so instead of failing silently', (
    tester,
  ) async {
    await _setUp(tasks: _QuickLogRefused());
    await _pump(tester);

    await _quickLog(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(await _logged(), isEmpty);
  });

  testWidgets('the message and the button are in French in French', (
    tester,
  ) async {
    await _setUp();
    await _pump(tester, locale: const Locale('fr'));

    await _quickLog(tester, label: 'Je viens de…');

    expect(find.text('Enregistrement de Dishes…'), findsOneWidget);
    expect(find.text('Annuler'), findsWidgets);
  });
}
