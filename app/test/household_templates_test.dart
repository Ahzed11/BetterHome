import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/widgets/chore_form_sections.dart';
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

Finder _field(String label) => find.widgetWithText(TextField, label);

/// Taps the stepper button named [tooltip] [times] times.
Future<void> _step(WidgetTester tester, String tooltip, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pump();
  }
}

/// Taps the icon button of the form until it shows [emoji] (an empty string is "none").
Future<void> _pickEmoji(WidgetTester tester, String emoji) async {
  final button = find
      .descendant(
        of: find.byType(ChoreDetailsCard),
        matching: find.byType(InkWell),
      )
      .first;
  for (var i = 0; i < 12; i++) {
    final shown = emoji.isEmpty
        ? find.byIcon(Icons.sentiment_satisfied_alt_outlined)
        : find.descendant(of: button, matching: find.text(emoji));
    if (shown.evaluate().isNotEmpty) {
      return;
    }
    await tester.tap(button);
    await tester.pump();
  }
  fail('icon $emoji is not offered');
}

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
    await tester.enterText(_field('Chore name'), 'Bins');
    await tester.enterText(_field('Notes — optional'), 'Every Monday');
    await _step(tester, 'Fewer On time', 2);
    await _step(tester, 'Fewer If late, still', 2);
    await tester.tap(find.text('Save template'));
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
      tester.widget<TextField>(_field('Chore name')).controller?.text,
      'Dishes',
    );
    await tester.enterText(_field('Chore name'), 'Dishes and pans');
    await _step(tester, 'More On time', 3);
    await tester.tap(find.text('Save template'));
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
    await _pickEmoji(tester, '');
    await tester.tap(find.text('Save template'));
    await tester.pumpAndSettle();

    expect((await _templates()).single.emoji, isNull);
  });

  testWidgets('cancelling changes nothing', (tester) async {
    await _setUp();
    await _pump(tester);

    await tester.tap(find.text('Dishes'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Chore name'), 'Other');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect((await _templates()).single.title, 'Dishes');
  });

  testWidgets('a blank name keeps saving disabled', (tester) async {
    await _setUp(withTemplate: false);
    await _pump(tester);

    await tester.tap(find.text('Add a template'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save template');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(_field('Chore name'), 'Bins');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(await _templates(), isEmpty);
  });

  testWidgets('late points never go above the on-time points', (tester) async {
    await _setUp(withTemplate: false);
    await _pump(tester);

    await tester.tap(find.text('Add a template'));
    await tester.pumpAndSettle();
    await _step(tester, 'Fewer On time', 7);

    // 10 - 7 = 3 on time; the 5 late points came down with it.
    final more = find.ancestor(
      of: find.byTooltip('More If late, still'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(more).onPressed, isNull);
  });

  testWidgets('a refused save is reported and nothing is added', (
    tester,
  ) async {
    await _setUp(tasks: _TemplateWritesRefused(), withTemplate: false);
    await _pump(tester);

    await tester.tap(find.text('Add a template'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Chore name'), 'Bins');
    await tester.pump();
    await tester.tap(find.text('Save template'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

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
