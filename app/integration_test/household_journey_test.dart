import 'package:betterhome/app.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Values come from `tooling/e2e.sh` (`--dart-define`), which also boots the stack and
/// signs the test user in against Keycloak. Same journey on every `E2E_TARGET`.
const _householdsUrl = String.fromEnvironment('E2E_HOUSEHOLDS_URL');
const _tasksUrl = String.fromEnvironment('E2E_TASKS_URL');
const _scoringUrl = String.fromEnvironment('E2E_SCORING_URL');
const _accessToken = String.fromEnvironment('E2E_ACCESS_TOKEN');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in profile sync, then create a household', (tester) async {
    final householdName = 'E2E home ${DateTime.now().millisecondsSinceEpoch}';
    final session = AppSession(
      repository: HttpHouseholdsRepository(
        baseUrl: _householdsUrl,
        accessToken: () => _accessToken,
      ),
      tasksRepository: HttpTasksRepository(
        baseUrl: _tasksUrl,
        accessToken: () => _accessToken,
      ),
      scoringRepository: HttpScoringRepository(
        baseUrl: _scoringUrl,
        accessToken: () => _accessToken,
      ),
    );

    await tester.pumpWidget(
      BetterHomeApp(session: session, initialLocale: const Locale('en')),
    );
    expect(find.text('Your profile'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Your households'), findsOneWidget);

    await tester.tap(find.text('Create household').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Household name'),
      householdName,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.textContaining(householdName), findsWidgets);
  });
}
