import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/widgets/quick_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

Future<void> _openSheet(
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
  final tasks = session.tasksRepository;
  for (final title in ['Dishes', 'Vacuum']) {
    await tasks.createTemplate(
      householdId: household.id,
      title: title,
      emoji: '🧽',
      points: 7,
      latePoints: 2,
    );
  }
  await pumpScreen(
    tester,
    home: ChoresScreen(session: session, householdId: household.id),
    locale: locale,
    textScale: textScale,
  );
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sheet lists every template with its points', (tester) async {
    await _openSheet(tester);

    expect(find.byType(QuickLogSheet), findsOneWidget);
    expect(
      find.text('One tap logs it. Full points, straight to you.'),
      findsOneWidget,
    );
    expect(find.text('Dishes'), findsOneWidget);
    expect(find.text('Vacuum'), findsOneWidget);
    expect(find.text('+7'), findsNWidgets(2));
  });

  testWidgets('searching narrows the templates', (tester) async {
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'vac');
    await tester.pumpAndSettle();

    expect(find.text('Vacuum'), findsOneWidget);
    expect(find.text('Dishes'), findsNothing);
  });

  testWidgets('closing the sheet logs nothing', (tester) async {
    await _openSheet(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(QuickLogSheet), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the sheet is in French in French', (tester) async {
    await _openSheet(tester, locale: const Locale('fr'));

    expect(find.text('Rechercher une tâche'), findsOneWidget);
    expect(find.byTooltip('Fermer'), findsOneWidget);
  });

  testWidgets('the sheet does not overflow at 200% text size', (tester) async {
    await _openSheet(tester, locale: const Locale('fr'), textScale: 2);

    expect(tester.takeException(), isNull);
  });
}
