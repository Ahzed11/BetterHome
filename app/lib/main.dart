import 'package:betterhome/app.dart';
import 'package:betterhome/auth/oidc_auth_service.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:flutter/material.dart';

/// Entry point. Runs in demo mode (in-memory repositories) unless both are set:
/// API: `--dart-define=API_BASE_URL=http://localhost:8081` (households), optionally
///   `TASKS_API_BASE_URL` (:8082) and `SCORING_API_BASE_URL` (:8083), which default to API_BASE_URL.
/// Sign-in: `--dart-define=KEYCLOAK_ISSUER=http://localhost:8180/realms/betterhome`,
///   optionally `KEYCLOAK_CLIENT_ID` (default `betterhome-app`).
/// On the Android emulator use 10.0.2.2 for the API and run `adb reverse tcp:8180 tcp:8180`, because
/// Keycloak advertises `localhost:8180` in its discovery document.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  const tasksApiBaseUrl = String.fromEnvironment('TASKS_API_BASE_URL');
  const scoringApiBaseUrl = String.fromEnvironment('SCORING_API_BASE_URL');
  const keycloakIssuer = String.fromEnvironment('KEYCLOAK_ISSUER');
  const keycloakClientId = String.fromEnvironment(
    'KEYCLOAK_CLIENT_ID',
    defaultValue: 'betterhome-app',
  );

  if (apiBaseUrl.isEmpty || keycloakIssuer.isEmpty) {
    runApp(
      BetterHomeApp(
        session: AppSession(repository: FakeHouseholdsRepository()),
      ),
    );
    return;
  }

  final auth = OidcAuthService.forPlatform(
    issuer: Uri.parse(keycloakIssuer),
    clientId: keycloakClientId,
  );
  runApp(
    BetterHomeApp(
      auth: auth,
      session: AppSession(
        repository: HttpHouseholdsRepository(
          baseUrl: apiBaseUrl,
          accessToken: auth.accessToken,
        ),
        tasksRepository: HttpTasksRepository(
          baseUrl: tasksApiBaseUrl.isEmpty ? apiBaseUrl : tasksApiBaseUrl,
          accessToken: auth.accessToken,
        ),
        scoringRepository: HttpScoringRepository(
          baseUrl: scoringApiBaseUrl.isEmpty ? apiBaseUrl : scoringApiBaseUrl,
          accessToken: auth.accessToken,
        ),
      ),
    ),
  );
}
