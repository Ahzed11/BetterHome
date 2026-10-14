import 'package:betterhome/app.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Values come from `tooling/e2e.sh` (`--dart-define`), which also boots the stack and
/// signs the test users in against Keycloak. Same journeys on every `E2E_TARGET`.
const _householdsUrl = String.fromEnvironment('E2E_HOUSEHOLDS_URL');
const _tasksUrl = String.fromEnvironment('E2E_TASKS_URL');
const _scoringUrl = String.fromEnvironment('E2E_SCORING_URL');
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
  await _see(tester, find.text('Your households'));
  return session;
}

Future<void> _createHousehold(WidgetTester tester, String name) async {
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
      await _tap(tester, find.textContaining(householdName));
      await _tap(tester, find.text('Open chores'));
      await _see(tester, find.textContaining('No chores yet'));

      // Admin creates a template (the household has none) and quick-logs a manual task.
      await _tap(tester, find.text('I just did…'));
      await _see(tester, find.text('New chore template'));
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Dishes');
      await _tap(tester, find.widgetWithText(FilledButton, 'Save'));
      await _tap(tester, find.widgetWithText(SimpleDialogOption, 'Dishes'));
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
      await _see(tester, find.text('open · 5 pts'));
      await _tap(tester, find.byTooltip('Complete'));
      await _seeCount(tester, find.text('done · 5 pts'), 2);
      await _back(tester);

      // Both completions show on the leaderboard, through tasks -> scoring over HTTP.
      await _tap(tester, find.text('Leaderboard'));
      await _see(tester, find.text('10 pts'));
      await _back(tester);

      // Dismissal asks for confirmation and awards nothing.
      await session.tasksRepository.createOpen(
        householdId: householdId,
        templateId: template.id,
      );
      await _tap(tester, find.text('Open chores'));
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
      await _back(tester);
      await _tap(tester, find.text('Leaderboard'));
      await _see(tester, find.text('5 pts'));
      expect(find.text('10 pts'), findsNothing);
    },
  );

  testWidgets('invite a member and join with the token', (tester) async {
    final alice = await _openAs(tester, _aliceToken, _aliceEmail);
    await _see(tester, find.textContaining(householdName));
    await _tap(tester, find.textContaining(householdName));
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
    await _tap(tester, find.textContaining('Bob home'));
    await _tap(tester, find.byTooltip('Accept invitation'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Invitation token'),
      token,
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Accept invitation'));

    final joined = await bob.repository.listMembers(householdId);
    expect(joined.map((m) => m.userId), contains(bob.profile?.id));
  });
}
