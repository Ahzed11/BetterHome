import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/create_household_screen.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/households_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/screens/profile_sync_screen.dart';
import 'package:betterhome/ui/screens/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/repository_doubles.dart';
import 'support/screen_harness.dart';

const String _household = 'hh-1';

/// A screen in one of its states, ready to be pumped.
class _Scenario {
  const _Scenario(this.name, this.build);

  final String name;
  final Future<Widget> Function() build;
}

/// Syncing the profile replaces the default tasks and scoring fakes, so the
/// doubles are installed afterwards.
Future<AppSession> _sessionWith({
  HouseholdsRepository? households,
  TasksRepository? tasks,
  ScoringRepository? scoring,
  ListsRepository? lists,
  bool withHousehold = true,
}) async {
  final session = AppSession(
    repository: households ?? FakeHouseholdsRepository(),
  );
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  if (withHousehold) {
    await session.repository.createHousehold(name: 'Flat', timezone: 'UTC');
  }
  if (tasks != null) {
    session.useTasksRepository(tasks);
  }
  if (scoring != null) {
    session.useScoringRepository(scoring);
  }
  if (lists != null) {
    session.useListsRepository(lists);
  }
  return session;
}

Future<AppSession> _choresSession({required bool populated}) async {
  final session = await _sessionWith();
  if (populated) {
    final tasks = session.tasksRepository;
    final sweep = await tasks.createTemplate(
      householdId: _household,
      title: 'Vacuum',
      emoji: '🧹',
      points: 5,
      latePoints: 2,
    );
    final dishes = await tasks.createTemplate(
      householdId: _household,
      title: 'Dishes',
      emoji: '🍽️',
      points: 3,
      latePoints: 1,
    );
    await tasks.createOpen(householdId: _household, templateId: sweep.id);
    await tasks.quickLog(householdId: _household, templateId: dishes.id);
  }
  return session;
}

Future<AppSession> _listsSession({required bool populated}) async {
  final session = await _sessionWith();
  if (populated) {
    final lists = session.listsRepository;
    final groceries = await lists.createList(_household, 'Groceries');
    await lists.createList(_household, 'Packing');
    final milk = await lists.addItem(_household, groceries.id, 'Milk');
    await lists.addItem(_household, groceries.id, 'Bread');
    await lists.checkItem(_household, groceries.id, milk.id);
  }
  return session;
}

final List<_Scenario> _scenarios = [
  _Scenario('sign_in', () async => SignInScreen(onSignIn: () {})),
  _Scenario(
    'sign_in_busy',
    () async => SignInScreen(onSignIn: () {}, busy: true),
  ),
  _Scenario(
    'sign_in_failed',
    () async => SignInScreen(onSignIn: () {}, failed: true),
  ),
  _Scenario(
    'profile_sync',
    () async => ProfileSyncScreen(
      session: AppSession(repository: FakeHouseholdsRepository()),
      onSynced: () {},
      onUseDemo: () {},
    ),
  ),
  _Scenario(
    'households_loading',
    () async => HouseholdsScreen(
      session: await _sessionWith(households: PendingHouseholdsRepository()),
    ),
  ),
  _Scenario(
    'households_empty',
    () async =>
        HouseholdsScreen(session: await _sessionWith(withHousehold: false)),
  ),
  _Scenario(
    'households_error',
    () async => HouseholdsScreen(
      session: await _sessionWith(households: FailingHouseholdsRepository()),
    ),
  ),
  _Scenario(
    'households_populated',
    () async => HouseholdsScreen(session: await _sessionWith()),
  ),
  _Scenario(
    'create_household',
    () async => CreateHouseholdScreen(session: await _sessionWith()),
  ),
  _Scenario(
    'household_detail_loading',
    () async => HouseholdDetailScreen(
      session: await _sessionWith(households: PendingHouseholdsRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'household_detail_error',
    () async => HouseholdDetailScreen(
      session: await _sessionWith(households: FailingHouseholdsRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'household_detail_populated',
    () async => HouseholdDetailScreen(
      session: await _sessionWith(),
      householdId: _household,
    ),
  ),
  _Scenario('household_detail_member_away', () async {
    final session = await _sessionWith();
    await session.repository.setAway(_household, 'user-1');
    return HouseholdDetailScreen(session: session, householdId: _household);
  }),
  _Scenario(
    'chores_loading',
    () async => ChoresScreen(
      session: await _sessionWith(tasks: PendingTasksRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'chores_error',
    () async => ChoresScreen(
      session: await _sessionWith(tasks: FailingTasksRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'chores_empty',
    () async => ChoresScreen(
      session: await _choresSession(populated: false),
      householdId: _household,
    ),
  ),
  _Scenario(
    'chores_populated',
    () async => ChoresScreen(
      session: await _choresSession(populated: true),
      householdId: _household,
    ),
  ),
  _Scenario(
    'leaderboard_loading',
    () async => LeaderboardScreen(
      session: await _sessionWith(scoring: PendingScoringRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'leaderboard_error',
    () async => LeaderboardScreen(
      session: await _sessionWith(scoring: FailingScoringRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'leaderboard_empty',
    () async => LeaderboardScreen(
      session: await _sessionWith(scoring: EmptyScoringRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'leaderboard_populated',
    () async => LeaderboardScreen(
      session: await _sessionWith(),
      householdId: _household,
    ),
  ),
  _Scenario(
    'lists_loading',
    () async => ListsScreen(
      session: await _sessionWith(lists: PendingListsRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'lists_error',
    () async => ListsScreen(
      session: await _sessionWith(lists: FailingListsRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'lists_empty',
    () async => ListsScreen(
      session: await _listsSession(populated: false),
      householdId: _household,
    ),
  ),
  _Scenario('lists_no_items', () async {
    final session = await _listsSession(populated: false);
    await session.listsRepository.createList(_household, 'Groceries');
    return ListsScreen(session: session, householdId: _household);
  }),
  _Scenario(
    'lists_populated',
    () async => ListsScreen(
      session: await _listsSession(populated: true),
      householdId: _household,
    ),
  ),
];

void main() {
  for (final scenario in _scenarios) {
    for (final locale in baselineLocales) {
      final id = '${scenario.name} (${locale.languageCode})';

      testWidgets('golden: $id', (tester) async {
        await pumpScreen(tester, home: await scenario.build(), locale: locale);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/${scenario.name}_${locale.languageCode}.png',
          ),
        );
      });

      testWidgets('accessibility: $id', (tester) async {
        await pumpScreen(tester, home: await scenario.build(), locale: locale);
        await expectAccessible(tester);
      });

      testWidgets('200% text scale does not overflow: $id', (tester) async {
        await pumpScreen(
          tester,
          home: await scenario.build(),
          locale: locale,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
