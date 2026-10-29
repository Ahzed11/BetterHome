import 'dart:async';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

const _household = 'hh-1';

DateTime _now() => DateTime.utc(2026, 10, 14, 10);

/// The requests that were started, in order. The doubles below record a request when it starts
/// and answer none of them: a request that is only started after another one is answered never
/// shows up, so the log proves which ones were asked together, without sleeping.
class _Log {
  final List<String> started = [];
  bool recording = false;

  Future<T> ask<T>(String name) {
    if (recording) {
      started.add(name);
    }
    return Completer<T>().future;
  }
}

class _LoggedHouseholds extends FakeHouseholdsRepository {
  _LoggedHouseholds(this.log);

  final _Log log;

  @override
  Future<Household> getHousehold(String householdId) => log.recording
      ? log.ask<Household>('household')
      : super.getHousehold(householdId);

  @override
  Future<List<Membership>> listMembers(String householdId) => log.recording
      ? log.ask<List<Membership>>('members')
      : super.listMembers(householdId);
}

/// A scoring repository that is not the demo fake, which needs the members before it can answer.
class _LoggedScoring implements ScoringRepository {
  _LoggedScoring(this.log);

  final _Log log;

  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) => log.ask<Scoreboard>('board');

  @override
  Future<List<MonthlyWinner>> listWinners(String householdId) =>
      log.ask<List<MonthlyWinner>>('winners');

  @override
  Future<void> markRecapCelebrated(String householdId, String yearMonth) =>
      log.ask<void>('celebrate');
}

class _LoggedTasks extends FakeTasksRepository {
  _LoggedTasks(this.log) : super(now: _now);

  final _Log log;

  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) => log.ask<List<ChoreTask>>('tasks');

  @override
  Future<TaskRecurrence?> getRecurrence(
    String householdId,
    String templateId,
  ) => log.ask<TaskRecurrence?>('recurrence');
}

Future<(AppSession, _Log)> _world({int templates = 0}) async {
  final log = _Log();
  final session = AppSession(repository: _LoggedHouseholds(log));
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  await session.repository.createHousehold(name: 'Flat', timezone: 'UTC');
  final tasks = _LoggedTasks(log);
  session.useTasksRepository(tasks);
  session.useScoringRepository(_LoggedScoring(log));
  for (var i = 0; i < templates; i++) {
    await tasks.createTemplate(
      householdId: _household,
      title: 'Chore $i',
      points: 5,
      latePoints: 2,
    );
  }
  log.recording = true;
  return (session, log);
}

Future<void> _show(WidgetTester tester, Widget home) =>
    pumpScreen(tester, home: home, locale: const Locale('en'));

void main() {
  testWidgets(
    'the leaderboard asks for the board, the winners, the members and the household together',
    (tester) async {
      final (session, log) = await _world();

      await _show(
        tester,
        LeaderboardScreen(session: session, householdId: _household),
      );

      expect(
        log.started,
        unorderedEquals(['board', 'winners', 'members', 'household']),
      );
    },
  );

  testWidgets(
    'my chores asks for the tasks, the members, the household and the week together',
    (tester) async {
      final (session, log) = await _world();

      await _show(
        tester,
        ChoresScreen(
          session: session,
          householdId: _household,
          mine: true,
          now: _now,
        ),
      );

      expect(
        log.started,
        unorderedEquals(['tasks', 'members', 'household', 'board']),
      );
    },
  );

  testWidgets(
    'all chores asks for the tasks and the members together, and no more',
    (tester) async {
      final (session, log) = await _world();

      await _show(
        tester,
        ChoresScreen(session: session, householdId: _household, now: _now),
      );

      expect(log.started, unorderedEquals(['tasks', 'members']));
    },
  );

  testWidgets(
    'the household screen asks for the household, the members and the rules together, and every recurrence together',
    (tester) async {
      final (session, log) = await _world(templates: 3);
      // The templates are answered at once (the double only holds the recurrences back), as the
      // recurrences can be asked only once the templates are known.
      await _show(
        tester,
        HouseholdDetailScreen(session: session, householdId: _household),
      );

      expect(
        log.started,
        unorderedEquals([
          'household',
          'members',
          'recurrence',
          'recurrence',
          'recurrence',
        ]),
      );
    },
  );

  testWidgets('each thing is asked for once in a visit', (tester) async {
    final (session, log) = await _world();

    await _show(
      tester,
      LeaderboardScreen(session: session, householdId: _household),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(log.started.toSet().length, log.started.length);
  });
}
