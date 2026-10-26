import 'dart:convert';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/server_config.dart';
import 'package:betterhome/server_app.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_service.dart';

const _address = 'https://home.example.com';

/// Answers the discovery request like a BetterHome server whose address is [_address].
http.Client _betterHome() => MockClient(
  (request) async => request.url.toString().startsWith(_address)
      ? http.Response(
          jsonEncode({'issuer': '$_address/auth/realms/betterhome'}),
          200,
        )
      : http.Response('', 404),
);

http.Client _nobody() =>
    MockClient((_) async => throw http.ClientException('no route'));

Future<List<ServerConfig>> _pump(
  WidgetTester tester, {
  Map<String, Object> stored = const {},
  http.Client? client,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final built = <ServerConfig>[];
  await tester.pumpWidget(
    ServerApp(
      preferences: await SharedPreferences.getInstance(),
      client: client ?? _betterHome(),
      initialLocale: locale,
      buildStack: (server) {
        built.add(server);
        return (
          auth: FakeAuthService(),
          session: AppSession(repository: FakeHouseholdsRepository()),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return built;
}

Future<void> _enter(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first launch asks for the server, nothing is built yet', (
    tester,
  ) async {
    final built = await _pump(tester);

    expect(find.text('Connect to your server'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(built, isEmpty);
  });

  testWidgets('an address that is not a web address is refused at once', (
    tester,
  ) async {
    final built = await _pump(tester);

    await _enter(tester, 'ftp://home.example.com');

    expect(find.textContaining('Enter a web address'), findsOneWidget);
    expect(built, isEmpty);
  });

  testWidgets('a server that does not answer is refused and not remembered', (
    tester,
  ) async {
    final built = await _pump(tester, client: _nobody());

    await _enter(tester, 'home.example.com');

    expect(find.textContaining('No BetterHome server answered'), findsOne);
    expect(built, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ServerApp.preferenceKey), isNull);
  });

  testWidgets('a BetterHome server is remembered and the sign-in shows it', (
    tester,
  ) async {
    final built = await _pump(tester);

    await _enter(tester, 'home.example.com');

    expect(built.single.toString(), _address);
    expect(find.text('Welcome to BetterHome'), findsOneWidget);
    expect(find.text('Server: home.example.com'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ServerApp.preferenceKey), _address);
  });

  testWidgets('the next launch goes straight to sign-in with the server', (
    tester,
  ) async {
    final built = await _pump(
      tester,
      stored: {ServerApp.preferenceKey: _address},
    );

    expect(find.text('Welcome to BetterHome'), findsOneWidget);
    expect(find.text('Server: home.example.com'), findsOneWidget);
    expect(find.text('Connect to your server'), findsNothing);
    expect(built.single.issuer, '$_address/auth/realms/betterhome');
  });

  testWidgets('a remembered value that is no longer an address is ignored', (
    tester,
  ) async {
    final built = await _pump(
      tester,
      stored: {ServerApp.preferenceKey: 'ftp://x'},
    );

    expect(find.text('Connect to your server'), findsOneWidget);
    expect(built, isEmpty);
  });

  testWidgets('"Change server" forgets the server and asks again', (
    tester,
  ) async {
    await _pump(tester, stored: {ServerApp.preferenceKey: _address});

    await tester.tap(find.text('Change server'));
    await tester.pumpAndSettle();

    expect(find.text('Connect to your server'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ServerApp.preferenceKey), isNull);
  });

  testWidgets('the demo needs no server', (tester) async {
    final built = await _pump(tester);

    await tester.tap(find.text('Continue with demo data'));
    await tester.pumpAndSettle();

    expect(find.text('Your profile'), findsOneWidget);
    expect(built, isEmpty);
  });

  testWidgets('it speaks French too', (tester) async {
    await _pump(tester, locale: const Locale('fr'));

    expect(find.text('Connectez-vous à votre serveur'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ftp://x');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Saisissez une adresse web'), findsOneWidget);
  });
}
