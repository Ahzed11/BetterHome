import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/create_household_screen.dart';
import 'package:betterhome/ui/widgets/timezone_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

class _Words {
  const _Words({
    required this.locale,
    required this.timezone,
    required this.name,
    required this.save,
    required this.title,
    required this.search,
    required this.noMatch,
  });

  final Locale locale;
  final String timezone;
  final String name;
  final String save;
  final String title;
  final String search;
  final String noMatch;
}

const _english = _Words(
  locale: Locale('en'),
  timezone: 'Timezone',
  name: 'Household name',
  save: 'Save',
  title: 'Choose a timezone',
  search: 'Search, for example Paris',
  noMatch: 'No timezone matches your search',
);

const _french = _Words(
  locale: Locale('fr'),
  timezone: 'Fuseau horaire',
  name: 'Nom du foyer',
  save: 'Enregistrer',
  title: 'Choisir un fuseau horaire',
  search: 'Rechercher, par exemple Paris',
  noMatch: 'Aucun fuseau horaire ne correspond à votre recherche',
);

Future<AppSession> _pump(WidgetTester tester, _Words words) async {
  final session = AppSession(repository: FakeHouseholdsRepository());
  await session.syncProfile(email: 'alice@example.com');
  await pumpScreen(
    tester,
    home: CreateHouseholdScreen(session: session),
    locale: words.locale,
  );
  return session;
}

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(TimezonePickerSheet), matching: finder);

Future<void> _open(WidgetTester tester, _Words words) async {
  await tester.tap(find.bySemanticsLabel(words.timezone));
  await tester.pumpAndSettle();
}

void main() {
  for (final words in [_english, _french]) {
    group('timezone picker (${words.locale.languageCode})', () {
      testWidgets('is a picker, not a text field, and starts on Europe/Paris', (
        tester,
      ) async {
        await _pump(tester, words);

        expect(find.byType(TextField), findsOneWidget); // the name only
        expect(find.text('Europe/Paris'), findsOneWidget);
      });

      testWidgets('opens scrolled to the current zone, marked as selected', (
        tester,
      ) async {
        await _pump(tester, words);
        await _open(tester, words);

        expect(find.text(words.title), findsOneWidget);
        expect(find.text(words.search), findsOneWidget);
        // The list opens on the current zone, which is far from the top of it.
        expect(_inSheet(find.text('Europe/Paris')), findsOneWidget);
        expect(find.text('Africa/Abidjan'), findsNothing);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('searching narrows the list and a tap chooses the zone', (
        tester,
      ) async {
        final session = await _pump(tester, words);
        await _open(tester, words);

        await tester.enterText(find.byType(TextField).last, 'brussels');
        await tester.pumpAndSettle();
        expect(find.text('Europe/Brussels'), findsOneWidget);
        expect(_inSheet(find.text('Europe/Paris')), findsNothing);

        await tester.tap(find.text('Europe/Brussels'));
        await tester.pumpAndSettle();
        expect(find.text(words.title), findsNothing);
        expect(find.text('Europe/Brussels'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, ''),
          'Flat ${words.locale.languageCode}',
        );
        await tester.tap(find.widgetWithText(FilledButton, words.save));
        await tester.pumpAndSettle();

        final created = (await session.repository.listHouseholds()).single;
        expect(created.timezone, 'Europe/Brussels');
      });

      testWidgets('a search without a match says so and offers no zone', (
        tester,
      ) async {
        await _pump(tester, words);
        await _open(tester, words);

        await tester.enterText(find.byType(TextField).last, 'Europe/Pariss');
        await tester.pumpAndSettle();

        expect(find.text(words.noMatch), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNothing);
      });

      testWidgets('closing the list without a choice keeps the zone', (
        tester,
      ) async {
        final session = await _pump(tester, words);
        await _open(tester, words);

        await tester.tapAt(
          const Offset(200, 20),
        ); // the barrier above the sheet
        await tester.pumpAndSettle();
        expect(find.text(words.title), findsNothing);
        expect(find.text('Europe/Paris'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Flat');
        await tester.tap(find.widgetWithText(FilledButton, words.save));
        await tester.pumpAndSettle();
        final created = (await session.repository.listHouseholds()).single;
        expect(created.timezone, 'Europe/Paris');
      });

      testWidgets('reopening marks the zone chosen last', (tester) async {
        await _pump(tester, words);
        await _open(tester, words);
        await tester.enterText(find.byType(TextField).last, 'tokyo');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Asia/Tokyo'));
        await tester.pumpAndSettle();

        await _open(tester, words);
        await tester.enterText(find.byType(TextField).last, 'tokyo');
        await tester.pumpAndSettle();

        final row = find.ancestor(
          of: find.text('Asia/Tokyo'),
          matching: find.byType(Row),
        );
        expect(
          find.descendant(of: row, matching: find.byIcon(Icons.check)),
          findsOneWidget,
        );
      });
    });
  }
}
