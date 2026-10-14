import 'package:betterhome/app.dart';
import 'package:betterhome/auth/auth_service.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_service.dart';

const _ada = AuthUser(
  subject: 'sub-ada',
  email: 'Ada@Example.com',
  givenName: 'Ada',
  familyName: 'Lovelace',
);

Future<AppSession> _pump(
  WidgetTester tester, {
  required FakeAuthService auth,
  FakeHouseholdsRepository? households,
  Locale locale = const Locale('en'),
}) async {
  final session = AppSession(
    repository: households ?? FakeHouseholdsRepository(),
  );
  await tester.pumpWidget(
    BetterHomeApp(session: session, auth: auth, initialLocale: locale),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('with no earlier session the sign-in screen is shown', (
    tester,
  ) async {
    final auth = FakeAuthService();

    await _pump(tester, auth: auth);

    expect(find.text('Welcome to BetterHome'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.textContaining('No households yet'), findsNothing);
  });

  testWidgets(
    'signing in creates the profile from the claims, then shows households',
    (tester) async {
      final auth = FakeAuthService(signsIn: _ada);
      final households = FakeHouseholdsRepository();

      final session = await _pump(tester, auth: auth, households: households);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No households yet'), findsOneWidget);
      expect(session.profile?.email, 'ada@example.com');
      expect(session.profile?.givenName, 'Ada');
      expect(session.profile?.language, 'en');
      expect(auth.signInCalls, 1);
    },
  );

  testWidgets('a later sign-in keeps the saved profile', (tester) async {
    final households = FakeHouseholdsRepository();
    await households.syncMe(
      email: 'ada@example.com',
      givenName: 'Saved',
      language: 'fr',
      timezone: 'Europe/Paris',
    );
    final auth = FakeAuthService(signsIn: _ada);

    final session = await _pump(tester, auth: auth, households: households);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No households yet'), findsOneWidget);
    expect(session.profile?.givenName, 'Saved');
    expect(session.profile?.language, 'fr');
    expect(session.profile?.timezone, 'Europe/Paris');
  });

  testWidgets('a session left by an earlier run skips the sign-in screen', (
    tester,
  ) async {
    final auth = FakeAuthService(restored: _ada);

    await _pump(tester, auth: auth);

    expect(find.textContaining('No households yet'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets(
    'closing the sign-in without finishing stays on the sign-in screen',
    (tester) async {
      final auth = FakeAuthService();

      await _pump(tester, auth: auth);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Sign-in did not complete. Try again.'), findsNothing);
    },
  );

  testWidgets('a failed sign-in says so and can be retried', (tester) async {
    final auth = FakeAuthService(failure: const AuthException('denied'));

    await _pump(tester, auth: auth);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in did not complete. Try again.'), findsOneWidget);

    auth
      ..failure = null
      ..signsIn = _ada;
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No households yet'), findsOneWidget);
  });

  testWidgets('signing out returns to the sign-in screen', (tester) async {
    final auth = FakeAuthService(restored: _ada);

    await _pump(tester, auth: auth);
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to BetterHome'), findsOneWidget);
    expect(auth.signOutCalls, 1);
    expect(auth.accessToken(), isEmpty);
  });

  testWidgets('the sign-in flow is available in French', (tester) async {
    final auth = FakeAuthService(signsIn: _ada);

    final session = await _pump(tester, auth: auth, locale: const Locale('fr'));
    expect(find.text('Bienvenue sur BetterHome'), findsOneWidget);
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Se déconnecter'), findsOneWidget);
    expect(session.profile?.language, 'fr');
  });

  testWidgets(
    'demo mode, without an identity provider, keeps the profile form',
    (tester) async {
      await tester.pumpWidget(
        MaterialAppFor(
          session: AppSession(repository: FakeHouseholdsRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your profile'), findsOneWidget);
    },
  );
}

/// The app without an identity provider.
class MaterialAppFor extends StatelessWidget {
  const MaterialAppFor({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) =>
      BetterHomeApp(session: session, initialLocale: const Locale('en'));
}
