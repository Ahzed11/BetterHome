import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

const _household = 'hh-1';

/// A household of three: the signed-in Ada, Bob Baker, and a member whose account has no name.
Future<AppSession> _session() async {
  final repository = FakeHouseholdsRepository();
  final session = AppSession(repository: repository);
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  await repository.createHousehold(name: 'Flat', timezone: 'UTC');
  repository
    ..addMember(
      _household,
      memberUserId: 'user-2',
      givenName: 'Bob',
      familyName: 'Baker',
    )
    ..addMember(
      _household,
      memberUserId: 'user-3',
      givenName: '',
      familyName: '',
    );
  return session;
}

void main() {
  test('a membership is named after its given and family names', () {
    final member = Membership(
      id: 'm',
      userId: 'u',
      householdId: 'h',
      role: MembershipRole.member,
      joinedAt: DateTime.utc(2026),
      givenName: 'Bob',
      familyName: 'Baker',
    );

    expect(member.displayName, 'Bob Baker');
  });

  testWidgets('household detail names members, not their ids', (tester) async {
    await pumpScreen(
      tester,
      home: HouseholdDetailScreen(
        session: await _session(),
        householdId: _household,
      ),
      locale: const Locale('en'),
    );

    expect(find.text('You'), findsWidgets);
    expect(find.text('Bob Baker'), findsOneWidget);
    expect(find.text('Household member'), findsOneWidget);
    expect(find.text('user-1'), findsNothing);
    expect(find.text('user-2'), findsNothing);
    expect(find.text('user-3'), findsNothing);
  });

  testWidgets('household detail falls back to a translated label', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      home: HouseholdDetailScreen(
        session: await _session(),
        householdId: _household,
      ),
      locale: const Locale('fr'),
    );

    expect(find.text('Vous'), findsWidgets);
    expect(find.text('Bob Baker'), findsOneWidget);
    expect(find.text('Membre du foyer'), findsOneWidget);
  });

  testWidgets('the leaderboard names members and only the user is You', (
    tester,
  ) async {
    final session = await _session();
    final scoring = FakeScoringRepository();
    await scoring.markRecapCelebrated(_household, '2026-09');
    session.useScoringRepository(scoring);
    await pumpScreen(
      tester,
      home: LeaderboardScreen(session: session, householdId: _household),
      locale: const Locale('en'),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Bob Baker'), findsWidgets);
    expect(find.text('You'), findsWidgets);
    expect(find.text('user-1'), findsNothing);
    expect(find.text('user-2'), findsNothing);
  });
}
