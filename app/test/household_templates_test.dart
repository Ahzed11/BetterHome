import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// Members of the household, all demoted to plain members: the signed-in person is not an admin.
class _EveryoneIsAMember extends FakeHouseholdsRepository {
  @override
  Future<List<Membership>> listMembers(String householdId) async => [
    for (final m in await super.listMembers(householdId))
      Membership(
        id: m.id,
        userId: m.userId,
        householdId: m.householdId,
        role: MembershipRole.member,
        joinedAt: m.joinedAt,
      ),
  ];
}

/// A tasks repository whose template writes are refused by the server.
class _TemplateWritesRefused extends FakeTasksRepository {
  @override
  Future<TaskTemplate> createTemplate({
    required String householdId,
    required String title,
    String? emoji,
    String description = '',
    required int points,
    required int latePoints,
  }) async => throw ApiException('refused', statusCode: 403);
}

late AppSession _session;
late String _household;

Future<void> _setUp({
  FakeHouseholdsRepository? households,
  FakeTasksRepository? tasks,
  bool withTemplate = true,
}) async {
  _session = AppSession(repository: households ?? FakeHouseholdsRepository());
  await _session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  if (tasks != null) {
    _session.useTasksRepository(tasks);
  }
  _household = (await _session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  )).id;
  if (withTemplate) {
    await _session.tasksRepository.createTemplate(
      householdId: _household,
      title: 'Dishes',
      emoji: '🍽️',
      points: 3,
      latePoints: 1,
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => pumpScreen(
  tester,
  home: HouseholdDetailScreen(session: _session, householdId: _household),
  locale: locale,
  textScale: textScale,
);

Future<List<TaskTemplate>> _templates() =>
    _session.tasksRepository.listTemplates(_household);

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('lists the templates with their points', (tester) async {
    await _setUp();
    await _pump(tester);

    expect(find.text('CHORE TEMPLATES'), findsOneWidget);
    expect(find.text('Dishes'), findsOneWidget);
    expect(find.text('3 pts · 1 if late'), findsOneWidget);
    expect(find.text('Add a template'), findsOneWidget);
  });

  testWidgets('says so when there is no template yet', (tester) async {
    await _setUp(withTemplate: false);
    await _pump(tester);

    expect(
      find.text('No templates yet. Add one to start logging chores.'),
      findsOneWidget,
    );
  });

  testWidgets('an admin adds a template', (tester) async {
    await _setUp(withTemplate: false);
    await _pump(tester);

    await tester.tap(find.text('Add a template'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Title'), 'Bins');
    await tester.enterText(_field('Emoji (optional)'), '🗑️');
    await tester.enterText(_field('Description (optional)'), 'Every Monday');
    await tester.enterText(_field('Points'), '8');
    await tester.enterText(_field('Points if late'), '3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final created = (await _templates()).single;
    expect(created.title, 'Bins');
    expect(created.emoji, '🗑️');
    expect(created.description, 'Every Monday');
    expect(created.points, 8);
    expect(created.latePoints, 3);
    expect(find.text('8 pts · 3 if late'), findsOneWidget);
  });

  testWidgets('an admin edits a template from its card', (tester) async {
    await _setUp();
    await _pump(tester);

    await tester.tap(find.text('Dishes'));
    await tester.pumpAndSettle();
    expect(find.text('Edit template'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(_field('Title')).controller?.text,
      'Dishes',
    );
    await tester.enterText(_field('Title'), 'Dishes and pans');
    await tester.enterText(_field('Points'), '6');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final edited = (await _templates()).single;
    expect(edited.title, 'Dishes and pans');
    expect(edited.points, 6);
    expect(edited.latePoints, 1, reason: 'untouched field is kept');
    expect(find.text('6 pts · 1 if late'), findsOneWidget);
  });

  testWidgets('clearing the emoji removes it', (tester) async {
    await _setUp();
    await _pump(tester);

    await tester.tap(find.text('Dishes'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Emoji (optional)'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await _templates()).single.emoji, isNull);
  });

  testWidgets('cancelling changes nothing', (tester) async {
    await _setUp();
    await _pump(tester);

    await tester.tap(find.text('Dishes'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Title'), 'Other');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect((await _templates()).single.title, 'Dishes');
  });

  testWidgets('a blank title or a bad number keeps the form open', (
    tester,
  ) async {
    await _setUp(withTemplate: false);
    await _pump(tester);

    await tester.tap(find.text('Add a template'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Points'), '-1');
    await tester.enterText(_field('Points if late'), 'abc');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a title'), findsOneWidget);
    expect(find.text('Enter a whole number, 0 or more'), findsNWidgets(2));
    expect(await _templates(), isEmpty);
  });

  testWidgets('a refused save is reported and nothing is added', (
    tester,
  ) async {
    await _setUp(tasks: _TemplateWritesRefused(), withTemplate: false);
    await _pump(tester);

    await tester.tap(find.text('Add a template'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Title'), 'Bins');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(await _templates(), isEmpty);
  });

  testWidgets('a member sees the templates but cannot change them', (
    tester,
  ) async {
    await _setUp(households: _EveryoneIsAMember());
    await _pump(tester);

    expect(find.text('Dishes'), findsOneWidget);
    expect(find.text('Add a template'), findsNothing);
    await tester.tap(find.text('Dishes'));
    await tester.pumpAndSettle();
    expect(find.text('Edit template'), findsNothing);
  });

  testWidgets('works in French at 200% text size without overflow', (
    tester,
  ) async {
    await _setUp();
    await _pump(tester, locale: const Locale('fr'), textScale: 2);

    await tester.scrollUntilVisible(find.text('Dishes'), 200);
    expect(find.text('MODÈLES DE TÂCHES'), findsOneWidget);
    expect(find.text('3 pts · 1 si en retard'), findsOneWidget);
    await tester.tap(find.text('Dishes'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le modèle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the templates section meets the accessibility guidelines', (
    tester,
  ) async {
    await _setUp();
    await _pump(tester);

    await expectAccessible(tester);
  });
}
