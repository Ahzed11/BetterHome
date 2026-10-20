import 'package:betterhome/app.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/widgets/add_field.dart';
import 'package:betterhome/ui/widgets/check_row.dart';
import 'package:betterhome/ui/widgets/household_switcher.dart';
import 'package:betterhome/ui/widgets/quick_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Values come from `tooling/e2e.sh` (`--dart-define`), which also boots the stack and
/// signs the test users in against Keycloak. Same journeys on every `E2E_TARGET`.
const _householdsUrl = String.fromEnvironment('E2E_HOUSEHOLDS_URL');
const _tasksUrl = String.fromEnvironment('E2E_TASKS_URL');
const _scoringUrl = String.fromEnvironment('E2E_SCORING_URL');
const _listsUrl = String.fromEnvironment('E2E_LISTS_URL');
const _notificationsUrl = String.fromEnvironment('E2E_NOTIFICATIONS_URL');
const _aliceToken = String.fromEnvironment('E2E_ACCESS_TOKEN');
const _bobToken = String.fromEnvironment('E2E_ACCESS_TOKEN_BOB');

const _aliceEmail = 'alice@betterhome.local';
const _bobEmail = 'bob@betterhome.local';

AppSession _sessionFor(String token) => AppSession(
  repository: HttpHouseholdsRepository(
    baseUrl: _householdsUrl,
    accessToken: () => token,
  ),
  tasksRepository: HttpTasksRepository(
    baseUrl: _tasksUrl,
    accessToken: () => token,
  ),
  scoringRepository: HttpScoringRepository(
    baseUrl: _scoringUrl,
    accessToken: () => token,
  ),
  listsRepository: HttpListsRepository(
    baseUrl: _listsUrl,
    accessToken: () => token,
  ),
  notificationsRepository: HttpNotificationsRepository(
    baseUrl: _notificationsUrl,
    accessToken: () => token,
  ),
);

/// Waits on real time until [finder] matches: the answers come from the network, which
/// `pumpAndSettle` does not wait for.
Future<void> _see(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets, reason: 'never appeared');
}

/// Like [_see], for when exactly [count] matches are expected.
Future<void> _seeCount(WidgetTester tester, Finder finder, int count) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().length == count) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, findsNWidgets(count));
}

/// Polls [condition] on real time: the relays that carry events between services run every 15 s.
Future<void> _waitFor(
  Future<bool> Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  fail('Timed out waiting for $what');
}

/// Goes back once the previous navigation has finished animating, so only one back button exists.
Future<void> _back(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _see(tester, finder);
  await tester.tap(finder.first);
  await tester.pump();
}

/// Taps [title] in the quick-log sheet once the sheet has finished sliding up: it is built at the
/// bottom edge, where a tap would miss it.
Future<void> _pickTemplate(WidgetTester tester, String title) async {
  await _see(tester, find.byType(QuickLogSheet));
  await tester.pumpAndSettle();
  await _tap(
    tester,
    find.descendant(of: find.byType(QuickLogSheet), matching: find.text(title)),
  );
}

/// Opens the app as [token]'s user, completes the profile step, and returns its session.
Future<AppSession> _openAs(
  WidgetTester tester,
  String token,
  String email,
) async {
  final session = _sessionFor(token);
  await tester.pumpWidget(
    // A new key per user, otherwise the previous user's app state is kept.
    BetterHomeApp(
      key: UniqueKey(),
      session: session,
      initialLocale: const Locale('en'),
    ),
  );
  await _see(tester, find.text('Your profile'));
  await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
  await _tap(tester, find.text('Continue'));
  await _see(
    tester,
    find.byWidgetPredicate(
      (w) =>
          w is NavigationBar ||
          (w is Text && (w.data ?? '').contains('No households yet')),
    ),
  );
  return session;
}

/// Makes [name] the household every tab shows, through the switcher.
Future<void> _selectHousehold(WidgetTester tester, String name) async {
  // The switcher bar is on the All chores tab only.
  if (find.byType(HouseholdSwitcher).evaluate().isEmpty &&
      find.byType(NavigationBar).evaluate().isNotEmpty) {
    await _tap(tester, find.text('All chores'));
  }
  await _see(tester, find.byType(HouseholdSwitcher));
  final current = tester
      .widget<HouseholdSwitcher>(find.byType(HouseholdSwitcher))
      .current;
  if (current.name == name) {
    return;
  }
  await _tap(tester, find.byType(HouseholdSwitcher));
  await _tap(
    tester,
    find.descendant(of: find.byType(HouseholdSheet), matching: find.text(name)),
  );
  await _see(
    tester,
    find.descendant(
      of: find.byType(HouseholdSwitcher),
      matching: find.text(name),
    ),
  );
}

/// Opens the details of the current household from the switcher sheet.
Future<void> _openDetails(WidgetTester tester) async {
  await _tap(tester, find.byType(HouseholdSwitcher));
  await _tap(tester, find.text('Household details'));
}

/// Creates a household: from the empty state of a new user, or from the switcher sheet.
Future<void> _createHousehold(WidgetTester tester, String name) async {
  if (find.byType(HouseholdSwitcher).evaluate().isNotEmpty) {
    await _tap(tester, find.byType(HouseholdSwitcher));
  }
  await _tap(tester, find.text('Create household'));
  await _see(tester, find.widgetWithText(TextField, 'Household name'));
  await tester.enterText(
    find.widgetWithText(TextField, 'Household name'),
    name,
  );
  await _tap(tester, find.widgetWithText(FilledButton, 'Save'));
  await _see(tester, find.textContaining(name));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final householdName = 'E2E home ${DateTime.now().millisecondsSinceEpoch}';
  late String householdId;

  testWidgets(
    'sign in profile sync, create a household, run chores and read the leaderboard',
    (tester) async {
      final session = await _openAs(tester, _aliceToken, _aliceEmail);
      await _createHousehold(tester, householdName);
      householdId = (await session.repository.listHouseholds())
          .firstWhere((h) => h.name == householdName)
          .id;

      // Alice is the only member, so every open task is hers.
      await _see(tester, find.textContaining('No chores yet'));

      // Admin creates a template (the household has none) and quick-logs a manual task.
      await _tap(tester, find.text('I just did…'));
      await _see(tester, find.text('New chore template'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Chore name'),
        'Dishes',
      );
      // The form starts at 10 points (5 if late); the journey's figures are 5 and 2.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Fewer On time'));
        await tester.pump();
      }
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Fewer If late, still'));
        await tester.pump();
      }
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Save chore'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await _tap(tester, find.widgetWithText(FilledButton, 'Save chore'));
      await _pickTemplate(tester, 'Dishes');

      // The log can be cancelled for five seconds: nothing reaches the server.
      await _see(tester, find.text('Logging Dishes…'));
      await _tap(tester, find.text('Undo'));
      await tester.pump(const Duration(seconds: 6));
      await Future<void>.delayed(const Duration(seconds: 6));
      await tester.pump();
      expect(await session.tasksRepository.listTasks(householdId), isEmpty);

      // Left alone, the log is sent when the five seconds pass.
      await _tap(tester, find.text('I just did…'));
      await _pickTemplate(tester, 'Dishes');
      await _see(tester, find.text('done · 5 pts'));

      // The assignee completes an open task.
      final template = (await session.tasksRepository.listTemplates(
        householdId,
      )).single;
      await session.tasksRepository.createOpen(
        householdId: householdId,
        templateId: template.id,
      );
      await _tap(tester, find.text('My chores'));
      await _see(tester, find.text('+5'));
      await _tap(tester, find.byTooltip('Complete'));
      await _seeCount(tester, find.text('done · 5 pts'), 2);

      // Both completions show on the leaderboard, through tasks -> scoring over HTTP.
      await _tap(tester, find.text('Leaderboard'));
      await _see(tester, find.text('10 pts'));

      // A chore past its due date is shown in soft coral with what is still possible.
      await session.tasksRepository.createOpen(
        householdId: householdId,
        templateId: template.id,
        dueAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      await _tap(tester, find.text('All chores'));
      await _see(tester, find.text('Overdue · still +2'));

      // Dismissal asks for confirmation and awards nothing.
      await _see(tester, find.byTooltip('Dismiss'));
      await tester.tap(find.byTooltip('Dismiss').first);
      await _see(tester, find.text('Dismiss this chore?'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Dismiss'));
      await _see(tester, find.textContaining('dismissed · '));

      // The admin reverts a completion with a reason; its points are taken back.
      await _tap(tester, find.byTooltip('Revert'));
      await _see(tester, find.widgetWithText(TextField, 'Reason'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason'),
        'Not clean',
      );
      await _tap(tester, find.widgetWithText(FilledButton, 'Revert'));
      await _seeCount(tester, find.byTooltip('Revert'), 1);
      // The assignee reads the admin's reason on the task.
      await _see(tester, find.text('Reverted: Not clean'));
      await _tap(tester, find.text('Leaderboard'));
      await _see(tester, find.text('5 pts'));
      expect(find.text('10 pts'), findsNothing);
    },
  );

  testWidgets('household switcher: two households each show their own chores', (
    tester,
  ) async {
    await _openAs(tester, _aliceToken, _aliceEmail);
    await _selectHousehold(tester, householdName);
    await _see(tester, find.textContaining('pts'));

    // A new household opens on its own, empty chores.
    final cabin = 'E2E cabin ${DateTime.now().millisecondsSinceEpoch}';
    await _createHousehold(tester, cabin);
    await _see(tester, find.textContaining('No chores yet'));

    // Switching back brings the first household's chores again, and the lists tab follows too.
    await _selectHousehold(tester, householdName);
    await _see(tester, find.textContaining('pts'));
    expect(find.textContaining('No chores yet'), findsNothing);
    await _selectHousehold(tester, cabin);
    await _tap(tester, find.text('Lists'));
    await _see(tester, find.text('No lists yet. An admin can create one.'));
  });

  testWidgets('lists: create a list, add, check, delete and reset items', (
    tester,
  ) async {
    final session = await _openAs(tester, _aliceToken, _aliceEmail);
    await _selectHousehold(tester, householdName);
    await _tap(tester, find.text('Lists'));
    await _see(tester, find.text('No lists yet. An admin can create one.'));

    // The admin creates a list.
    await _tap(tester, find.byTooltip('New list'));
    await tester.enterText(
      find.widgetWithText(TextField, 'List name'),
      'Weekly shop',
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Save'));
    await _see(tester, find.text('Weekly shop · 0'));

    // Any member adds items.
    // A new finder per use: a finder keeps the elements it found first.
    Finder field() => find.descendant(
      of: find.byType(AddField),
      matching: find.byType(TextField),
    );
    for (final item in ['Milk', 'Bread']) {
      // Tapping the Add button of the previous round took the focus: put it back first.
      await tester.tap(field());
      await tester.pump();
      await tester.enterText(field(), item);
      await _tap(tester, find.byTooltip('Add'));
      await _see(tester, find.text(item));
    }
    await _see(tester, find.text('Weekly shop · 2'));

    // Checking moves an item to the basket.
    Finder boxOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(CheckRow)),
      matching: find.byType(InkResponse),
    );
    await _tap(tester, boxOf('Milk'));
    await _see(tester, find.text('IN THE BASKET · 1'));
    await _see(tester, find.text('Weekly shop · 1'));

    // Deleting removes it for good.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Bread'),
          matching: find.byType(CheckRow),
        ),
        matching: find.byTooltip('Delete item'),
      ),
    );
    await _seeCount(tester, find.text('Bread'), 0);

    // Resetting asks first, then unchecks everything.
    await _tap(tester, find.text('Uncheck all'));
    await _see(tester, find.text('Uncheck every item?'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Uncheck all'));
    await _see(tester, find.text('Weekly shop · 1'));
    expect(find.text('IN THE BASKET · 1'), findsNothing);

    final lists = await session.listsRepository.listLists(householdId);
    final items = await session.listsRepository.listItems(
      householdId,
      lists.single.id,
    );
    expect(items.map((i) => i.title), ['Milk']);
    expect(items.single.isChecked, isFalse);
  });

  testWidgets('invite a member and join with the token', (tester) async {
    final alice = await _openAs(tester, _aliceToken, _aliceEmail);
    await _selectHousehold(tester, householdName);
    await _openDetails(tester);
    await _tap(tester, find.byTooltip('Invite'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Email to invite'),
      _bobEmail,
    );
    await _tap(tester, find.text('Send invitation'));
    await _see(tester, find.textContaining('Token: '));
    final shown =
        tester.widget<Text>(find.textContaining('Token: ')).data ?? '';
    final token = shown.substring('Token: '.length);
    expect(token, isNotEmpty);
    expect(alice.lastError, isNull);

    // Bob signs in to his own session, makes a home to stand in, and accepts the invitation there.
    final bob = await _openAs(tester, _bobToken, _bobEmail);
    await _createHousehold(
      tester,
      'Bob home ${DateTime.now().millisecondsSinceEpoch}',
    );
    await _openDetails(tester);
    await _tap(tester, find.byTooltip('Accept invitation'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Invitation token'),
      token,
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Accept invitation'));

    // The request is still on its way when the tap returns: wait until bob is a member.
    await _waitFor(() async {
      try {
        final members = await bob.repository.listMembers(householdId);
        return members.any((m) => m.userId == bob.profile?.id);
      } on ApiException {
        return false;
      }
    }, 'bob to be a member of the household');
  });

  testWidgets(
    'notifications: an event reaches the inbox, is read and a setting changes',
    (tester) async {
      // Alice (admin) marks bob away through the API; the households outbox relays it to
      // notifications-service within a few seconds.
      final alice = _sessionFor(_aliceToken);
      final bobApi = _sessionFor(_bobToken);
      final bobId = (await bobApi.repository.getMe()).id;
      await alice.repository.setAway(householdId, bobId);
      await _waitFor(
        () async => (await bobApi.notificationsRepository.list(
          unreadOnly: true,
        )).isNotEmpty,
        'the away notification in bob\'s inbox',
      );

      // Bob sees the dot, opens the inbox and reads the notification.
      await _openAs(tester, _bobToken, _bobEmail);
      await _tap(tester, find.byTooltip('Notifications, unread'));
      await _see(tester, find.text('Marked away'));
      await _see(tester, find.textContaining('dismissed'));
      await _tap(tester, find.text('Marked away'));
      await _seeCount(tester, find.text('Mark all read'), 0);
      expect(
        await bobApi.notificationsRepository.list(unreadOnly: true),
        isEmpty,
      );

      // A setting changes and is saved on the server.
      await _tap(tester, find.byTooltip('Notification settings'));
      await _see(tester, find.byType(Switch));
      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      await _waitFor(() async {
        final saved = await bobApi.notificationsRepository.preferences();
        return saved.any((p) => !p.enabled);
      }, 'the switched-off preference');

      // Back on the home screen the dot is gone.
      await _back(tester);
      await _back(tester);
      await _see(tester, find.byTooltip('Notifications'));
    },
  );
}
