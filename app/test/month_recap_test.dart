import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

const _household = 'hh-1';

/// A scoring repository that answers with the given winners and records what was marked seen.
class _Recaps extends FakeScoringRepository {
  _Recaps(this._winners, {this.rejectMark = false})
    : super(memberIds: ['user-1']);

  final List<MonthlyWinner> _winners;
  final bool rejectMark;
  final List<String> marked = [];

  @override
  Future<List<MonthlyWinner>> listWinners(String householdId) async => [
    for (final w in _winners)
      MonthlyWinner(
        yearMonth: w.yearMonth,
        winnerUserId: w.winnerUserId,
        winnerPoints: w.winnerPoints,
        totalPoints: w.totalPoints,
        celebrated: w.celebrated || marked.contains(w.yearMonth),
      ),
  ];

  @override
  Future<void> markRecapCelebrated(String householdId, String yearMonth) async {
    if (rejectMark) {
      throw ApiException('boom', statusCode: 500);
    }
    marked.add(yearMonth);
  }
}

Future<AppSession> _session(ScoringRepository scoring) async {
  final session = AppSession(
    repository: FakeHouseholdsRepository(),
    scoringRepository: scoring,
  );
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  await session.repository.createHousehold(name: 'Flat', timezone: 'UTC');
  (session.repository as FakeHouseholdsRepository).addMember(
    _household,
    memberUserId: 'user-2',
    givenName: 'Bob',
    familyName: 'Baker',
  );
  // Syncing the profile replaces the scoring fake; the test's own repository goes back in.
  session.useScoringRepository(scoring);
  return session;
}

Future<void> _open(
  WidgetTester tester,
  AppSession session, {
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  await pumpScreen(
    tester,
    // A new key per visit: the screen starts from scratch, as when it is opened again.
    home: LeaderboardScreen(
      key: UniqueKey(),
      session: session,
      householdId: _household,
    ),
    locale: locale,
    settle: settle,
  );
  await tester.pump(const Duration(milliseconds: 600));
}

MonthlyWinner _winner(
  String month,
  String? user,
  int points, {
  int total = 30,
  bool celebrated = false,
}) => MonthlyWinner(
  yearMonth: month,
  winnerUserId: user,
  winnerPoints: points,
  totalPoints: total,
  celebrated: celebrated,
);

void main() {
  testWidgets('the winner sees that they won, with the household total', (
    tester,
  ) async {
    final scoring = _Recaps([_winner('2026-09', 'user-1', 20, total: 35)]);
    await _open(tester, await _session(scoring));

    expect(find.text('Month recap · September 2026'), findsOneWidget);
    expect(find.text('You won September 2026 with 20 points!'), findsOneWidget);
    expect(find.text('Together you earned 35 points.'), findsOneWidget);
    expect(find.text('Nice!'), findsOneWidget);
    expect(scoring.marked, ['2026-09']);
  });

  testWidgets('everyone else sees who won', (tester) async {
    final scoring = _Recaps([_winner('2026-09', 'user-2', 20)]);
    await _open(tester, await _session(scoring));

    expect(
      find.text('Bob Baker won September 2026 with 20 points.'),
      findsOneWidget,
    );
  });

  testWidgets('a month nobody scored in says so and has no total', (
    tester,
  ) async {
    final scoring = _Recaps([_winner('2026-09', null, 0, total: 0)]);
    await _open(tester, await _session(scoring));

    expect(find.text('Nobody scored in September 2026.'), findsOneWidget);
    expect(find.textContaining('Together'), findsNothing);
  });

  testWidgets(
    'closing the recap shows the board and the recap does not come back',
    (tester) async {
      final scoring = _Recaps([_winner('2026-09', 'user-1', 20)]);
      final session = await _session(scoring);
      await _open(tester, session);

      await tester.tap(find.text('Nice!'));
      await tester.pumpAndSettle();
      expect(find.text('Nice!'), findsNothing);

      await _open(tester, session);
      await tester.pumpAndSettle();

      expect(find.text('Month recap · September 2026'), findsNothing);
      expect(scoring.marked, ['2026-09'], reason: 'recorded once');
    },
  );

  testWidgets('an already seen recap is not shown', (tester) async {
    final scoring = _Recaps([
      _winner('2026-09', 'user-1', 20, celebrated: true),
    ]);
    await _open(tester, await _session(scoring));
    await tester.pumpAndSettle();

    expect(find.text('Nice!'), findsNothing);
    expect(scoring.marked, isEmpty);
  });

  testWidgets(
    'with several unseen months the newest comes first, the next on the next visit',
    (tester) async {
      final scoring = _Recaps([
        _winner('2026-09', 'user-1', 20),
        _winner('2026-08', 'user-2', 12),
      ]);
      final session = await _session(scoring);

      await _open(tester, session);
      expect(find.text('Month recap · September 2026'), findsOneWidget);
      await tester.tap(find.text('Nice!'));
      await tester.pumpAndSettle();
      await _open(tester, session);

      expect(find.text('Month recap · August 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'if the server cannot record it the recap is not shown, and a message is',
    (tester) async {
      final scoring = _Recaps([
        _winner('2026-09', 'user-1', 20),
      ], rejectMark: true);
      await _open(tester, await _session(scoring), settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Nice!'), findsNothing);
      expect(find.text('Something went wrong'), findsOneWidget);
    },
  );

  testWidgets('a failing leaderboard shows its error and no recap', (
    tester,
  ) async {
    await _open(tester, await _session(_FailingScoring()));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Nice!'), findsNothing);
  });

  testWidgets('the recap is available in French', (tester) async {
    final scoring = _Recaps([_winner('2026-09', 'user-1', 20, total: 35)]);
    await _open(tester, await _session(scoring), locale: const Locale('fr'));

    expect(find.text('Bilan du mois · septembre 2026'), findsOneWidget);
    expect(
      find.text('Vous avez remporté septembre 2026 avec 20 points !'),
      findsOneWidget,
    );
    expect(find.text('Super !'), findsOneWidget);
  });
}

class _FailingScoring extends FakeScoringRepository {
  _FailingScoring() : super(memberIds: ['user-1']);

  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) async => throw ApiException('boom', statusCode: 500);
}
