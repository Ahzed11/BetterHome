import 'dart:async';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/server_config.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/create_household_screen.dart';
import 'package:betterhome/ui/screens/delete_account_screen.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/screens/notification_preferences_screen.dart';
import 'package:betterhome/ui/screens/notifications_screen.dart';
import 'package:betterhome/ui/screens/profile_sync_screen.dart';
import 'package:betterhome/ui/screens/server_setup_screen.dart';
import 'package:betterhome/ui/screens/sign_in_screen.dart';
import 'package:betterhome/ui/screens/template_form_screen.dart';
import 'package:betterhome/ui/widgets/app_toast.dart';
import 'package:betterhome/ui/widgets/household_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/repository_doubles.dart';
import 'support/screen_harness.dart';

const String _household = 'hh-1';

/// The day every golden is rendered on (a Tuesday), so the week strip, due dates and "Today" do not move with the date.
DateTime _now() => DateTime.utc(2026, 10, 20, 12);

/// A screen in one of its states, ready to be pumped.
class _Scenario {
  const _Scenario(this.name, this.build, {this.act});

  final String name;
  final Future<Widget> Function() build;

  /// Drives the pumped screen into the state to check (a dialog open, a toast showing).
  final Future<void> Function(WidgetTester tester, AppLocalizations l10n)? act;
}

/// Pumps [scenario] and runs its [_Scenario.act], if any.
Future<void> _pumpScenario(
  WidgetTester tester,
  _Scenario scenario,
  Locale locale, {
  double textScale = 1,
  bool realFonts = false,
}) async {
  await pumpScreen(
    tester,
    home: await scenario.build(),
    locale: locale,
    textScale: textScale,
    realFonts: realFonts,
  );
  final act = scenario.act;
  if (act != null) {
    await act(
      tester,
      AppLocalizations.of(tester.element(find.byType(Scaffold).first)),
    );
  }
}

/// A household of two members seen by the second one, who is a plain member: the fake
/// repository only knows its own user, so the admin who created the household is added here.
class _MemberViewHouseholdsRepository extends FakeHouseholdsRepository {
  _MemberViewHouseholdsRepository() : super(userId: 'user-2');

  @override
  Future<List<Membership>> listMembers(String householdId) async => [
    Membership(
      id: 'm-admin',
      userId: 'user-1',
      householdId: householdId,
      role: MembershipRole.admin,
      joinedAt: DateTime.utc(2025, 12, 1),
    ),
    Membership(
      id: 'm-member',
      userId: 'user-2',
      householdId: householdId,
      role: MembershipRole.member,
      joinedAt: DateTime.utc(2026, 1, 1),
    ),
  ];
}

Future<AppSession> _memberSession() =>
    _sessionWith(households: _MemberViewHouseholdsRepository());

/// Shows a toast from the screen under test and lets it slide in, leaving its timer running.
Future<void> _toast(
  WidgetTester tester, {
  required String message,
  String? actionLabel,
  bool error = false,
}) async {
  unawaited(
    showAppToast(
      tester.element(find.byType(Scaffold).first),
      message: message,
      actionLabel: actionLabel,
      error: error,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Types [address] into the server field and taps Continue, scrolling to the button first: at large
/// text sizes it is below the fold.
Future<void> _submitServer(
  WidgetTester tester,
  AppLocalizations l10n,
  String address,
) async {
  // The text field has a Scrollable of its own: scroll the page, the first one.
  final page = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(
    find.byType(TextField),
    100,
    scrollable: page,
  );
  await tester.enterText(find.byType(TextField), address);
  final button = find.widgetWithText(FilledButton, l10n.continueLabel);
  await tester.scrollUntilVisible(button, 100, scrollable: page);
  await _tap(tester, button);
}

/// The server setup screen with the answer of the server check decided by [check].
Widget _serverSetup(Future<bool> Function(ServerConfig) check) =>
    ServerSetupScreen(check: check, onSaved: (_) {}, onDemo: () {});

/// Taps the delete-account button, scrolling to it first: at large text sizes it is below the fold.
Future<void> _tapDeleteAccount(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final button = find.widgetWithText(FilledButton, l10n.deleteAccount);
  await tester.scrollUntilVisible(button, 100);
  await _tap(tester, button);
}

/// A second person in the household, named by the members API, besides the signed-in one.
void _addBob(AppSession session) =>
    (session.repository as FakeHouseholdsRepository).addMember(
      _household,
      memberUserId: 'user-2',
      givenName: 'Bob',
      familyName: 'Baker',
    );

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
    tasksRepository: FakeTasksRepository(now: _now),
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

/// Opens the options sheet of the selected list.
Future<void> _openListOptions(WidgetTester tester, AppLocalizations l10n) =>
    _tap(tester, find.byTooltip(l10n.listOptions));

/// Opens the options sheet and taps one of its rows.
Future<void> _chooseListOption(
  WidgetTester tester,
  AppLocalizations l10n,
  String title,
) async {
  await _openListOptions(tester, l10n);
  await _tap(
    tester,
    find.descendant(of: find.byType(BottomSheet), matching: find.text(title)),
  );
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
  createdAt: DateTime(2026, 10, 14, 10),
  readAt: read ? DateTime(2026, 10, 14, 11) : null,
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
  _Scenario('server_setup', () async => _serverSetup((_) async => true)),
  _Scenario(
    'server_setup_invalid',
    () async => _serverSetup((_) async => true),
    act: (tester, l10n) => _submitServer(tester, l10n, 'ftp://home'),
  ),
  _Scenario(
    'server_setup_unreachable',
    () async => _serverSetup((_) async => false),
    act: (tester, l10n) => _submitServer(tester, l10n, 'home.example.com'),
  ),
  _Scenario(
    'server_setup_checking',
    () async => _serverSetup((_) => Completer<bool>().future),
    act: (tester, l10n) => _submitServer(tester, l10n, 'home.example.com'),
  ),
  _Scenario(
    'sign_in_server',
    () async => SignInScreen(
      onSignIn: () {},
      serverHost: 'home.example.com',
      onChangeServer: () {},
    ),
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
    () async => HomeShell(session: await _sessionWith(), now: _now),
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
    return ChoresScreen(now: _now, session: session, householdId: _household);
  }),
  _Scenario('chores_reverted', () async {
    final session = await _choresSession(populated: true);
    final tasks = session.tasksRepository;
    final done = (await tasks.listTasks(
      _household,
    )).firstWhere((t) => t.status == TaskStatus.done);
    await tasks.revert(_household, done.id, reason: 'Not clean');
    return ChoresScreen(now: _now, session: session, householdId: _household);
  }),
  _Scenario(
    'chores_mine',
    () async => ChoresScreen(
      now: _now,
      session: await _choresSession(populated: true),
      householdId: _household,
      mine: true,
    ),
  ),
  _Scenario(
    'template_form',
    () async => TemplateFormScreen(
      session: await _sessionWith(),
      householdId: _household,
    ),
  ),
  _Scenario(
    'recurring_form',
    () async => TemplateFormScreen(
      session: await _sessionWith(),
      householdId: _household,
      startRecurring: true,
    ),
  ),
  _Scenario(
    'create_household',
    () async => CreateHouseholdScreen(session: await _sessionWith()),
  ),
  _Scenario(
    'create_household_timezone_picker',
    () async => CreateHouseholdScreen(session: await _sessionWith()),
    act: (tester, l10n) async {
      await tester.tap(find.bySemanticsLabel(l10n.timezone));
      await tester.pumpAndSettle();
    },
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
  _Scenario('household_detail_populated', () async {
    final session = await _sessionWith();
    _addBob(session);
    return HouseholdDetailScreen(session: session, householdId: _household);
  }),
  _Scenario('household_detail_templates', () async {
    final session = await _sessionWith();
    final tasks = session.tasksRepository;
    await tasks.createTemplate(
      householdId: _household,
      title: 'Vacuum',
      emoji: '🧹',
      points: 5,
      latePoints: 2,
    );
    await tasks.createTemplate(
      householdId: _household,
      title: 'Dishes',
      points: 3,
      latePoints: 1,
    );
    return HouseholdDetailScreen(session: session, householdId: _household);
  }),
  _Scenario('household_detail_member_away', () async {
    final session = await _sessionWith();
    await session.repository.setAway(_household, 'user-1');
    return HouseholdDetailScreen(session: session, householdId: _household);
  }),
  _Scenario(
    'chores_loading',
    () async => ChoresScreen(
      now: _now,
      session: await _sessionWith(tasks: PendingTasksRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'chores_error',
    () async => ChoresScreen(
      now: _now,
      session: await _sessionWith(tasks: FailingTasksRepository()),
      householdId: _household,
    ),
  ),
  _Scenario(
    'chores_empty',
    () async => ChoresScreen(
      now: _now,
      session: await _choresSession(populated: false),
      householdId: _household,
    ),
  ),
  _Scenario(
    'chores_populated',
    () async => ChoresScreen(
      now: _now,
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
    final session = await _sessionWith(scoring: scoring);
    _addBob(session);
    return LeaderboardScreen(session: session, householdId: _household);
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
    'lists_new_list_dialog',
    () async => ListsScreen(
      session: await _listsSession(populated: true),
      householdId: _household,
    ),
    act: (tester, l10n) async {
      await _tap(tester, find.byTooltip(l10n.newList));
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Pantry',
      );
      await tester.pumpAndSettle();
    },
  ),
  _Scenario(
    'lists_rename_dialog',
    () async => ListsScreen(
      session: await _listsSession(populated: true),
      householdId: _household,
    ),
    act: (tester, l10n) => _chooseListOption(tester, l10n, l10n.renameList),
  ),
  _Scenario(
    'lists_archive_dialog',
    () async => ListsScreen(
      session: await _listsSession(populated: true),
      householdId: _household,
    ),
    act: (tester, l10n) => _chooseListOption(tester, l10n, l10n.archiveList),
  ),
  _Scenario(
    'lists_options_sheet',
    () async => ListsScreen(
      session: await _listsSession(populated: true),
      householdId: _household,
    ),
    act: _openListOptions,
  ),
  _Scenario('lists_options_sheet_member', () async {
    final session = await _sessionWith(
      households: _MemberViewHouseholdsRepository(),
    );
    final lists = session.listsRepository;
    final groceries = await lists.createList(_household, 'Groceries');
    await lists.addItem(_household, groceries.id, 'Milk');
    return ListsScreen(session: session, householdId: _household);
  }, act: _openListOptions),
  _Scenario('lists_all_checked', () async {
    final session = await _listsSession(populated: true);
    final lists = session.listsRepository;
    final groceries = (await lists.listLists(_household)).first;
    for (final item in await lists.listItems(_household, groceries.id)) {
      if (!item.isChecked) {
        await lists.checkItem(_household, groceries.id, item.id);
      }
    }
    return ListsScreen(session: session, householdId: _household);
  }),
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
  _Scenario('notification_settings_push_on', () async {
    final repo = FakeNotificationsRepository();
    await repo.registerPushTarget('token');
    return NotificationPreferencesScreen(
      session: await _sessionWith(notifications: repo),
    );
  }),
  _Scenario(
    'household_detail_member',
    () async => HouseholdDetailScreen(
      session: await _memberSession(),
      householdId: _household,
    ),
  ),
  _Scenario('household_detail_member_templates', () async {
    final session = await _memberSession();
    await session.tasksRepository.createTemplate(
      householdId: _household,
      title: 'Vacuum',
      points: 5,
      latePoints: 2,
    );
    return HouseholdDetailScreen(session: session, householdId: _household);
  }),
  _Scenario('chores_member', () async {
    final session = await _memberSession();
    final tasks = session.tasksRepository;
    final vacuum = await tasks.createTemplate(
      householdId: _household,
      title: 'Vacuum',
      points: 5,
      latePoints: 2,
    );
    final dishes = await tasks.createTemplate(
      householdId: _household,
      title: 'Dishes',
      points: 3,
      latePoints: 1,
    );
    await tasks.createOpen(householdId: _household, templateId: vacuum.id);
    await tasks.quickLog(householdId: _household, templateId: dishes.id);
    return ChoresScreen(now: _now, session: session, householdId: _household);
  }),
  _Scenario(
    'invite_dialog',
    () async => HouseholdDetailScreen(
      session: await _sessionWith(),
      householdId: _household,
    ),
    act: (tester, l10n) async {
      await _tap(tester, find.text(l10n.inviteHousemate));
      await tester.enterText(find.byType(TextField), 'bob@example.com');
      await tester.pumpAndSettle();
    },
  ),
  _Scenario(
    'invite_created_dialog',
    () async => HouseholdDetailScreen(
      session: await _sessionWith(),
      householdId: _household,
    ),
    act: (tester, l10n) async {
      await _tap(tester, find.text(l10n.inviteHousemate));
      await tester.enterText(find.byType(TextField), 'bob@example.com');
      await _tap(tester, find.text(l10n.sendInvite));
    },
  ),
  _Scenario(
    'accept_invite_dialog',
    () async => HouseholdDetailScreen(
      session: await _sessionWith(),
      householdId: _household,
    ),
    act: (tester, l10n) async {
      await _tap(tester, find.byTooltip(l10n.acceptInvite));
      await tester.enterText(find.byType(TextField), 'token-1');
      await tester.pumpAndSettle();
    },
  ),
  _Scenario(
    'dismiss_confirm_dialog',
    () async => ChoresScreen(
      now: _now,
      session: await _choresSession(populated: true),
      householdId: _household,
    ),
    act: (tester, l10n) async {
      await _tap(tester, find.byTooltip(l10n.dismissTask).first);
    },
  ),
  _Scenario(
    'revert_dialog',
    () async => ChoresScreen(
      now: _now,
      session: await _choresSession(populated: true),
      householdId: _household,
    ),
    act: (tester, l10n) async {
      await _tap(tester, find.byTooltip(l10n.revertTask).first);
      await tester.enterText(find.byType(TextField), 'Not clean');
      await tester.pumpAndSettle();
    },
  ),
  _Scenario(
    'delete_account',
    () async =>
        DeleteAccountScreen(session: await _sessionWith(), onDeleted: () {}),
  ),
  _Scenario(
    'delete_account_confirm_dialog',
    () async =>
        DeleteAccountScreen(session: await _sessionWith(), onDeleted: () {}),
    act: (tester, l10n) async {
      await _tapDeleteAccount(tester, l10n);
    },
  ),
  _Scenario(
    'delete_account_sole_admin',
    () async {
      final session = await _sessionWith();
      _addBob(session);
      return DeleteAccountScreen(session: session, onDeleted: () {});
    },
    act: (tester, l10n) async {
      await _tapDeleteAccount(tester, l10n);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.deleteAccount),
        ),
      );
      await tester.pumpAndSettle();
    },
  ),
  _Scenario(
    'toast_spawned',
    () async => HouseholdDetailScreen(
      session: await _sessionWith(),
      householdId: _household,
    ),
    act: (tester, l10n) async {
      await tester.tap(find.text(l10n.runDueNow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    },
  ),
  _Scenario(
    'toast_recurrence_set',
    () async => HouseholdDetailScreen(
      session: await _sessionWith(),
      householdId: _household,
    ),
    act: (tester, l10n) => _toast(tester, message: l10n.recurrenceSet),
  ),
  _Scenario(
    'toast_undo',
    () async => ChoresScreen(
      now: _now,
      session: await _choresSession(populated: true),
      householdId: _household,
    ),
    act: (tester, l10n) => _toast(
      tester,
      message: l10n.quickLogPending('Dishes'),
      actionLabel: l10n.undo,
    ),
  ),
  _Scenario(
    'toast_error',
    () async => ChoresScreen(
      now: _now,
      session: await _choresSession(populated: true),
      householdId: _household,
    ),
    act: (tester, l10n) =>
        _toast(tester, message: l10n.errorGeneric, error: true),
  ),
];

void main() {
  for (final scenario in _scenarios) {
    for (final locale in baselineLocales) {
      final id = '${scenario.name} (${locale.languageCode})';

      testWidgets('accessibility: $id', (tester) async {
        await _pumpScenario(tester, scenario, locale);
        await expectAccessible(tester);
      });

      testWidgets('200% text scale does not overflow: $id', (tester) async {
        await _pumpScenario(tester, scenario, locale, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scenario in _scenarios) {
    for (final locale in baselineLocales) {
      final id = '${scenario.name} (${locale.languageCode})';

      testWidgets('golden: $id', (tester) async {
        await _pumpScenario(tester, scenario, locale, realFonts: true);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/${scenario.name}_${locale.languageCode}.png',
          ),
        );
      });
    }
  }
}
