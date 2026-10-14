import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/create_household_screen.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/screens/notification_preferences_screen.dart';
import 'package:betterhome/ui/screens/notifications_screen.dart';
import 'package:betterhome/ui/screens/profile_sync_screen.dart';
import 'package:betterhome/ui/screens/sign_in_screen.dart';
import 'package:betterhome/ui/widgets/household_switcher.dart';
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
  NotificationsRepository? notifications,
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
  if (notifications != null) {
    session.useNotificationsRepository(notifications);
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

AppNotification _notification(
  String id,
  String title,
  String body, {
  bool read = false,
}) => AppNotification(
  id: id,
  type: NotificationType.taskAssigned,
  title: title,
  body: body,
  createdAt: DateTime.utc(2026, 10, 14, 10),
  readAt: read ? DateTime.utc(2026, 10, 14, 11) : null,
);

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
    'home_loading',
    () async => HomeShell(
      session: await _sessionWith(households: PendingHouseholdsRepository()),
    ),
  ),
  _Scenario(
    'home_no_household',
    () async => HomeShell(session: await _sessionWith(withHousehold: false)),
  ),
  _Scenario(
    'home_error',
    () async => HomeShell(
      session: await _sessionWith(households: FailingHouseholdsRepository()),
    ),
  ),
  _Scenario(
    'home_populated',
    () async => HomeShell(session: await _sessionWith()),
  ),
  _Scenario('household_sheet', () async {
    final session = await _sessionWith();
    final second = await session.repository.createHousehold(
      name: 'Cabin',
      timezone: 'Europe/Paris',
    );
    final households = await session.repository.listHouseholds();
    return Scaffold(
      body: HouseholdSheet(current: second, households: households),
    );
  }),
  _Scenario('chores_overdue', () async {
    final session = await _choresSession(populated: true);
    final templates = await session.tasksRepository.listTemplates(_household);
    await session.tasksRepository.createOpen(
      householdId: _household,
      templateId: templates.first.id,
      dueAt: DateTime.utc(2020),
    );
    return ChoresScreen(session: session, householdId: _household);
  }),
  _Scenario('chores_reverted', () async {
    final session = await _choresSession(populated: true);
    final tasks = session.tasksRepository;
    final done = (await tasks.listTasks(
      _household,
    )).firstWhere((t) => t.status == TaskStatus.done);
    await tasks.revert(_household, done.id, reason: 'Not clean');
    return ChoresScreen(session: session, householdId: _household);
  }),
  _Scenario(
    'chores_mine',
    () async => ChoresScreen(
      session: await _choresSession(populated: true),
      householdId: _household,
      mine: true,
    ),
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
  _Scenario('leaderboard_populated', () async {
    // The September recap was seen already, so the board itself is what the golden shows.
    final scoring = FakeScoringRepository();
    await scoring.markRecapCelebrated(_household, '2026-09');
    return LeaderboardScreen(
      session: await _sessionWith(scoring: scoring),
      householdId: _household,
    );
  }),
  _Scenario(
    'leaderboard_recap',
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
  _Scenario(
    'notifications_loading',
    () async => NotificationsScreen(
      session: await _sessionWith(
        notifications: PendingNotificationsRepository(),
      ),
    ),
  ),
  _Scenario(
    'notifications_error',
    () async => NotificationsScreen(
      session: await _sessionWith(
        notifications: FailingNotificationsRepository(),
      ),
    ),
  ),
  _Scenario(
    'notifications_empty',
    () async => NotificationsScreen(session: await _sessionWith()),
  ),
  _Scenario('notifications_populated', () async {
    final repo = FakeNotificationsRepository()
      ..add(_notification('1', 'Reminder', '"Vacuum" is due soon.', read: true))
      ..add(_notification('2', 'New chore', '"Dishes" is yours.'));
    return NotificationsScreen(
      session: await _sessionWith(notifications: repo),
    );
  }),
  _Scenario(
    'notification_settings_loading',
    () async => NotificationPreferencesScreen(
      session: await _sessionWith(
        notifications: PendingNotificationsRepository(),
      ),
    ),
  ),
  _Scenario(
    'notification_settings_error',
    () async => NotificationPreferencesScreen(
      session: await _sessionWith(
        notifications: FailingNotificationsRepository(),
      ),
    ),
  ),
  _Scenario('notification_settings_populated', () async {
    final repo = FakeNotificationsRepository();
    await repo.setPreference(
      NotificationType.dueReminder,
      NotificationChannel.push,
      enabled: false,
    );
    return NotificationPreferencesScreen(
      session: await _sessionWith(notifications: repo),
    );
  }),
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
