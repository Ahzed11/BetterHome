import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/delete_account_screen.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

class _BrokenDeletion extends FakeHouseholdsRepository {
  @override
  Future<void> deleteMyAccount() async =>
      throw ApiException('boom', statusCode: 500);
}

Future<(AppSession, FakeHouseholdsRepository)> _session({
  FakeHouseholdsRepository? repository,
}) async {
  final repo = repository ?? FakeHouseholdsRepository();
  final session = AppSession(repository: repo);
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  return (session, repo);
}

Future<void> _tapDelete(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

void main() {
  group('fake repository follows the server rules', () {
    test('a sole admin with other members is refused', () async {
      final (session, repo) = await _session();
      await session.repository.createHousehold(name: 'Flat', timezone: 'UTC');
      repo.addMember(
        'hh-1',
        memberUserId: 'user-2',
        givenName: 'Bob',
        familyName: 'Baker',
      );

      await expectLater(
        repo.deleteMyAccount(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      expect(await repo.listHouseholds(), hasLength(1));
    });

    test('leaves shared households and deletes sole-member ones', () async {
      final (session, repo) = await _session();
      await session.repository.createHousehold(name: 'Alone', timezone: 'UTC');
      await session.repository.createHousehold(name: 'Shared', timezone: 'UTC');
      repo.addMember(
        'hh-2',
        memberUserId: 'user-2',
        givenName: 'Bob',
        familyName: 'Baker',
        role: MembershipRole.admin,
      );

      await repo.deleteMyAccount();

      expect((await repo.listHouseholds()).map((h) => h.name), ['Shared']);
      expect((await repo.listMembers('hh-2')).map((m) => m.userId), ['user-2']);
      await expectLater(repo.getMe(), throwsA(isA<ApiException>()));
    });
  });

  group('delete account screen', () {
    testWidgets('explains the deletion and does nothing until confirmed', (
      tester,
    ) async {
      final (session, repo) = await _session();
      await pumpScreen(
        tester,
        home: DeleteAccountScreen(session: session, onDeleted: () {}),
        locale: const Locale('en'),
      );

      expect(find.textContaining('removes your name and email'), findsOne);
      await _tapDelete(tester, 'Delete my account');
      expect(find.text('Delete your account?'), findsOne);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your account?'), findsNothing);
      await expectLater(repo.getMe(), completes);
    });

    testWidgets('a confirmed deletion closes the screen and reports it', (
      tester,
    ) async {
      final (session, repo) = await _session();
      var deleted = 0;
      await pumpScreen(
        tester,
        home: DeleteAccountScreen(session: session, onDeleted: () => deleted++),
        locale: const Locale('en'),
      );

      await _tapDelete(tester, 'Delete my account');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete my account'),
        ),
      );
      await tester.pumpAndSettle();

      expect(deleted, 1);
      await expectLater(repo.getMe(), throwsA(isA<ApiException>()));
    });

    testWidgets('a sole admin is told to hand over first, in French too', (
      tester,
    ) async {
      final (session, repo) = await _session();
      await session.repository.createHousehold(name: 'Flat', timezone: 'UTC');
      repo.addMember(
        'hh-1',
        memberUserId: 'user-2',
        givenName: 'Bob',
        familyName: 'Baker',
      );
      var deleted = 0;
      await pumpScreen(
        tester,
        home: DeleteAccountScreen(session: session, onDeleted: () => deleted++),
        locale: const Locale('fr'),
      );

      await _tapDelete(tester, 'Supprimer mon compte');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Supprimer mon compte'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('seul administrateur'), findsOne);
      expect(deleted, 0);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Supprimer mon compte'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('any other failure shows the generic error', (tester) async {
      final (session, _) = await _session(repository: _BrokenDeletion());
      var deleted = 0;
      await pumpScreen(
        tester,
        home: DeleteAccountScreen(session: session, onDeleted: () => deleted++),
        locale: const Locale('en'),
      );

      await _tapDelete(tester, 'Delete my account');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete my account'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOne);
      expect(deleted, 0);
    });
  });

  group('home shell', () {
    testWidgets('offers account deletion only when the app signs in', (
      tester,
    ) async {
      final (session, _) = await _session();
      await session.repository.createHousehold(name: 'Flat', timezone: 'UTC');
      await pumpScreen(
        tester,
        home: HomeShell(session: session),
        locale: const Locale('en'),
      );
      expect(find.byTooltip('Delete my account'), findsNothing);

      await pumpScreen(
        tester,
        home: HomeShell(session: session, onAccountDeleted: () {}),
        locale: const Locale('en'),
      );
      expect(find.byTooltip('Delete my account'), findsOne);
    });
  });
}
