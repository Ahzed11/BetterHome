import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/template_form_screen.dart';
import 'package:betterhome/ui/widgets/chore_form_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

late AppSession _session;
late String _household;

/// A page with a button that opens the form and saves what it returns, like the real callers.
class _Host extends StatelessWidget {
  const _Host({this.template, this.startRecurring = false});

  final TaskTemplate? template;
  final bool startRecurring;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () async {
          final draft = await Navigator.of(context).push<TemplateDraft>(
            MaterialPageRoute(
              builder: (_) => TemplateFormScreen(
                session: _session,
                householdId: _household,
                template: template,
                startRecurring: startRecurring,
              ),
            ),
          );
          if (draft != null && context.mounted) {
            await saveTemplateDraft(
              context,
              _session,
              _household,
              draft,
              template: template,
            );
          }
        },
        child: const Text('open'),
      ),
    ),
  );
}

Future<void> _open(
  WidgetTester tester, {
  TaskTemplate? template,
  bool startRecurring = false,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  _session = AppSession(repository: FakeHouseholdsRepository());
  await _session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  _household = (await _session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  )).id;
  await pumpScreen(
    tester,
    home: _Host(template: template, startRecurring: startRecurring),
    locale: locale,
    textScale: textScale,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<Finder> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  return finder;
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(
    await _scrollTo(tester, find.widgetWithText(FilledButton, 'Save chore')),
  );
  await tester.pumpAndSettle();
}

Future<TaskRecurrence?> _recurrenceOfOnlyTemplate() async {
  final template = (await _session.tasksRepository.listTemplates(
    _household,
  )).single;
  return _session.tasksRepository.getRecurrence(_household, template.id);
}

void main() {
  testWidgets('a chore does not repeat unless asked', (tester) async {
    await _open(tester);

    expect(find.text('WHEN'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Bins');
    await _save(tester);

    expect(await _recurrenceOfOnlyTemplate(), isNull);
  });

  testWidgets('the repeat switch shows the schedule and who does it', (
    tester,
  ) async {
    await _open(tester);

    await tester.tap(await _scrollTo(tester, find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(find.text('WHEN'), findsOneWidget);
    expect(find.text('WHO DOES IT'), findsOneWidget);
  });

  testWidgets('saves a chore and a weekly rotation', (tester) async {
    await _open(tester, startRecurring: true);

    await tester.enterText(find.byType(TextField).first, 'Bins');
    await tester.tap(
      await _scrollTo(tester, find.byTooltip('Increase interval')),
    );
    await tester.pump();
    await _save(tester);

    final recurrence = await _recurrenceOfOnlyTemplate();
    expect(recurrence?.rrule, startsWith('FREQ=WEEKLY;INTERVAL=2;BYDAY='));
    expect(recurrence?.assignmentMode, AssignmentMode.roundRobin);
  });

  testWidgets('daily and monthly rules', (tester) async {
    await _open(tester, startRecurring: true);
    await tester.enterText(find.byType(TextField).first, 'Plants');

    await tester.tap(await _scrollTo(tester, find.text('Monthly')));
    await tester.pump();
    await _save(tester);

    expect(
      (await _recurrenceOfOnlyTemplate())?.rrule,
      'FREQ=MONTHLY;BYMONTHDAY=1',
    );
  });

  testWidgets('one person needs someone picked and is saved as fixed', (
    tester,
  ) async {
    await _open(tester, startRecurring: true);
    await tester.enterText(find.byType(TextField).first, 'Bins');
    await tester.tap(await _scrollTo(tester, find.text('One person')));
    await tester.pumpAndSettle();

    final save = await _scrollTo(
      tester,
      find.widgetWithText(FilledButton, 'Save chore'),
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(await _scrollTo(tester, find.text('You')));
    await tester.pump();
    await _save(tester);

    final recurrence = await _recurrenceOfOnlyTemplate();
    expect(recurrence?.assignmentMode, AssignmentMode.fixed);
    expect(recurrence?.fixedAssigneeId, _session.profile?.id);
  });

  testWidgets('a template that repeats opens with its schedule', (
    tester,
  ) async {
    _session = AppSession(repository: FakeHouseholdsRepository());
    await _session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
    _household = (await _session.repository.createHousehold(
      name: 'Flat',
      timezone: 'UTC',
    )).id;
    final template = await _session.tasksRepository.createTemplate(
      householdId: _household,
      title: 'Bins',
      points: 4,
      latePoints: 1,
    );
    await _session.tasksRepository.upsertRecurrence(
      householdId: _household,
      templateId: template.id,
      rrule: 'FREQ=DAILY;INTERVAL=3',
      assignmentMode: AssignmentMode.roundRobin,
    );
    await pumpScreen(
      tester,
      home: _Host(template: template),
      locale: const Locale('en'),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(await _scrollTo(tester, find.text('3 days')), findsOneWidget);
    final switchTile = tester.widget<Switch>(
      await _scrollTo(tester, find.byType(Switch)),
    );
    expect(switchTile.value, isTrue);
    expect(switchTile.onChanged, isNull, reason: 'it cannot be turned off');
  });

  testWidgets('the icon button opens a picker and the choice is saved', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField).first, 'Plants');

    await tester.tap(
      find.descendant(
        of: find.byType(ChoreDetailsCard),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose an icon'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Garden and pets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🪴'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(
      (await _session.tasksRepository.listTemplates(_household)).single.emoji,
      '🪴',
    );
  });

  testWidgets('the picker can also choose no icon', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField).first, 'Plants');
    await tester.tap(
      find.descendant(
        of: find.byType(ChoreDetailsCard),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('No icon'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(
      (await _session.tasksRepository.listTemplates(_household)).single.emoji,
      isNull,
    );
  });

  testWidgets('the form is in French in French at 200% text size', (
    tester,
  ) async {
    await _open(
      tester,
      startRecurring: true,
      locale: const Locale('fr'),
      textScale: 2,
    );

    expect(find.text('Nouveau modèle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
