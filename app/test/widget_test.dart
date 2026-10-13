import 'package:betterhome/app.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('English empty households after demo sync', (tester) async {
    final session = AppSession(repository: FakeHouseholdsRepository());
    await tester.pumpWidget(
      BetterHomeApp(session: session, initialLocale: const Locale('en')),
    );

    expect(find.text('Your profile'), findsOneWidget);
    await tester.tap(find.text('Continue with demo data'));
    await tester.pumpAndSettle();

    expect(find.text('Your households'), findsOneWidget);
    expect(find.textContaining('No households yet'), findsOneWidget);
  });

  testWidgets('French create household flow', (tester) async {
    final session = AppSession(repository: FakeHouseholdsRepository());
    await tester.pumpWidget(
      BetterHomeApp(session: session, initialLocale: const Locale('fr')),
    );

    await tester.tap(find.text('Continuer avec des données de démo'));
    await tester.pumpAndSettle();

    expect(find.text('Vos foyers'), findsOneWidget);
    await tester.tap(find.text('Créer un foyer'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Coloc');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Coloc'), findsOneWidget);
  });

  testWidgets('Invite and mark away on detail screen', (tester) async {
    final repo = FakeHouseholdsRepository();
    final session = AppSession(repository: repo);
    await session.syncProfile(email: 'admin@example.com', givenName: 'Ada');
    await repo.createHousehold(name: 'Flat', timezone: 'UTC');

    await tester.pumpWidget(
      BetterHomeApp(session: session, initialLocale: const Locale('en')),
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flat'));
    await tester.pumpAndSettle();

    expect(find.text('Members'), findsOneWidget);
    await tester.tap(find.byTooltip('Invite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(find.text('Send invitation'));
    await tester.pumpAndSettle();
    expect(find.text('Invitation created'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark away'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Away'), findsWidgets);
  });

  test('localizations include both languages', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('fr')));
  });

  testWidgets('quick-log chore from household detail', (tester) async {
    final session = AppSession(repository: FakeHouseholdsRepository());
    await tester.pumpWidget(
      BetterHomeApp(session: session, initialLocale: const Locale('en')),
    );
    await tester.tap(find.text('Continue with demo data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create household'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Flat');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open chores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I just did…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chore'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chore'), findsWidgets);
  });

  testWidgets('leaderboard shows podium and effort bar', (tester) async {
    final session = AppSession(repository: FakeHouseholdsRepository());
    await tester.pumpWidget(
      BetterHomeApp(session: session, initialLocale: const Locale('en')),
    );
    await tester.tap(find.text('Continue with demo data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create household'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Flat');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leaderboard'));
    await tester.pumpAndSettle();
    expect(find.text('Podium'), findsOneWidget);
    expect(find.text('Shared effort'), findsOneWidget);
    expect(find.text('Hall of winners'), findsOneWidget);
  });

  testWidgets('admin sets daily recurrence from chores menu', (tester) async {
    final session = AppSession(repository: FakeHouseholdsRepository());
    await tester.pumpWidget(
      BetterHomeApp(session: session, initialLocale: const Locale('en')),
    );
    await tester.tap(find.text('Continue with demo data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create household'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Flat');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open chores'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make recurring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    expect(find.text('Recurrence saved'), findsOneWidget);
  });

  testWidgets('French leaderboard labels', (tester) async {
    final session = AppSession(repository: FakeHouseholdsRepository());
    await tester.pumpWidget(
      BetterHomeApp(session: session, initialLocale: const Locale('fr')),
    );
    await tester.tap(find.text('Continuer avec des données de démo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un foyer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Coloc');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coloc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Classement'));
    await tester.pumpAndSettle();
    expect(find.text('Podium'), findsOneWidget);
    expect(find.text('Effort partagé'), findsOneWidget);
    expect(find.text('Palmarès'), findsOneWidget);
  });
}
