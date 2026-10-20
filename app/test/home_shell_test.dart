import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

Future<AppSession> _session({
  List<String> households = const ['Flat', 'Cabin'],
  FakeHouseholdsRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues({});
  return _sessionOn(
    repository ?? FakeHouseholdsRepository(),
    households: households,
  );
}

Future<AppSession> _sessionOn(
  FakeHouseholdsRepository repository, {
  List<String> households = const [],
}) async {
  final session = AppSession(
    repository: repository,
    preferences: await SharedPreferences.getInstance(),
  );
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  for (final name in households) {
    await session.repository.createHousehold(name: name, timezone: 'UTC');
  }
  return session;
}

Future<void> _pumpShell(
  WidgetTester tester,
  AppSession session, {
  Locale locale = const Locale('en'),
}) => pumpScreen(
  tester,
  home: HomeShell(session: session),
  locale: locale,
);

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pumpAndSettle();
}

Finder _switcher(String name) =>
    find.bySemanticsLabel('Household $name, switch household');

void main() {
  group('tabs', () {
    testWidgets('open on all chores with four tabs and the first household', (
      tester,
    ) async {
      await _pumpShell(tester, await _session());

      expect(find.byType(NavigationBar), findsOneWidget);
      for (final label in ['All chores', 'My chores', 'Leaderboard', 'Lists']) {
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Flat'), findsOneWidget);
      expect(
        find.text('No chores yet. Quick-log something you just did.'),
        findsOneWidget,
      );
    });

    testWidgets('only the chores tab has the switcher bar', (tester) async {
      await _pumpShell(tester, await _session());
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);

      await _openTab(tester, 'My chores');
      expect(find.byType(AppBar), findsNothing);
      expect(find.byTooltip('Notifications'), findsNothing);

      await _openTab(tester, 'Lists');
      expect(find.byType(AppBar), findsNothing);

      await _openTab(tester, 'All chores');
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('each tab shows its own screen', (tester) async {
      await _pumpShell(tester, await _session());

      await _openTab(tester, 'Leaderboard');
      expect(find.text('Shared effort'), findsOneWidget);
      await _tapText(tester, 'Nice!'); // the unseen month recap

      await _openTab(tester, 'Lists');
      expect(
        find.text('No lists yet. An admin can create one.'),
        findsOneWidget,
      );

      await _openTab(tester, 'My chores');
      expect(
        find.text('No chores yet. Quick-log something you just did.'),
        findsOneWidget,
      );
    });

    testWidgets('the tabs are in French in French', (tester) async {
      await _pumpShell(tester, await _session(), locale: const Locale('fr'));

      expect(find.text('Classement'), findsOneWidget);
      expect(find.text('Listes'), findsOneWidget);
      expect(find.text('Mes tâches'), findsOneWidget);
    });

    testWidgets('the chores of the household are listed on the chores tabs', (
      tester,
    ) async {
      final session = await _session(households: ['Flat']);
      final flat = (await session.repository.listHouseholds()).single;
      final tasks = session.tasksRepository;
      final template = await tasks.createTemplate(
        householdId: flat.id,
        title: 'Vacuum',
        points: 5,
        latePoints: 2,
      );
      await tasks.createOpen(householdId: flat.id, templateId: template.id);

      await _pumpShell(tester, session);
      expect(find.text('Vacuum'), findsOneWidget);

      await _openTab(tester, 'My chores');
      expect(find.text('My chores'), findsWidgets);
    });
  });

  group('household switcher', () {
    testWidgets('lists the households and switches every tab to the choice', (
      tester,
    ) async {
      final session = await _session();
      final tasks = session.tasksRepository;
      final cabin = (await session.repository.listHouseholds()).last;
      final template = await tasks.createTemplate(
        householdId: cabin.id,
        title: 'Chop wood',
        points: 5,
        latePoints: 2,
      );
      await tasks.createOpen(householdId: cabin.id, templateId: template.id);
      await _pumpShell(tester, session);
      expect(find.text('Chop wood'), findsNothing);

      await tester.tap(_switcher('Flat'));
      await tester.pumpAndSettle();
      expect(find.text('Flat'), findsWidgets);
      expect(find.text('Cabin'), findsOneWidget);

      await tester.tap(find.text('Cabin'));
      await tester.pumpAndSettle();

      expect(_switcher('Cabin'), findsOneWidget);
      expect(find.text('Chop wood'), findsOneWidget);
      expect(session.selectedHouseholdId, cabin.id);
    });

    testWidgets('the choice is remembered after a restart', (tester) async {
      final repository = FakeHouseholdsRepository();
      final first = await _session(repository: repository);
      await _pumpShell(tester, first);
      await tester.tap(_switcher('Flat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cabin'));
      await tester.pumpAndSettle();

      final restarted = await _sessionOn(repository);
      await tester.pumpWidget(const SizedBox());
      await _pumpShell(tester, restarted);

      expect(_switcher('Cabin'), findsOneWidget);
    });

    testWidgets('a remembered household that is gone falls back to the first', (
      tester,
    ) async {
      final repository = FakeHouseholdsRepository();
      final first = await _session(repository: repository);
      final cabin = (await repository.listHouseholds()).last;
      await first.selectHousehold(cabin.id);
      await repository.leave(cabin.id);

      final restarted = await _sessionOn(repository);
      await _pumpShell(tester, restarted);

      expect(_switcher('Flat'), findsOneWidget);
    });

    testWidgets('creating a household from the sheet switches to it', (
      tester,
    ) async {
      await _pumpShell(tester, await _session(households: ['Flat']));

      await tester.tap(_switcher('Flat'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Create household');
      await tester.enterText(find.byType(TextField).first, 'Cabin');
      await _tapText(tester, 'Save');

      expect(_switcher('Cabin'), findsOneWidget);
    });

    testWidgets('household details open from the sheet', (tester) async {
      await _pumpShell(tester, await _session(households: ['Flat']));

      await tester.tap(_switcher('Flat'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Household details');

      expect(find.text('MEMBERS'), findsOneWidget);
      expect(find.text('Leave household'), findsOneWidget);
    });

    testWidgets('leaving the last household shows the empty state', (
      tester,
    ) async {
      await _pumpShell(tester, await _session(households: ['Flat']));
      await tester.tap(_switcher('Flat'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Household details');

      await _tapText(tester, 'Leave household');

      expect(find.textContaining('No households yet'), findsOneWidget);
    });
  });

  group('without a household', () {
    testWidgets('offers to create one, and creating it opens the tabs', (
      tester,
    ) async {
      await _pumpShell(tester, await _session(households: const []));

      expect(find.textContaining('No households yet'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await _tapText(tester, 'Create household');
      await tester.enterText(find.byType(TextField).first, 'Flat');
      await _tapText(tester, 'Save');

      expect(_switcher('Flat'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('selection', () {
    test('keeps the selection while it exists, else the first', () async {
      final session = await _session();
      final households = await session.repository.listHouseholds();

      session.ensureSelection(households);
      expect(session.selectedHouseholdId, households.first.id);

      await session.selectHousehold(households.last.id);
      session.ensureSelection(households);
      expect(session.selectedHouseholdId, households.last.id);

      session.ensureSelection([households.first]);
      expect(session.selectedHouseholdId, households.first.id);

      session.ensureSelection(const <Household>[]);
      expect(session.selectedHouseholdId, isNull);
    });
  });
}
