import 'package:betterhome/app.dart';
import 'package:betterhome/server_app.dart';
import 'package:betterhome/server_stack.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry point. The server is chosen in one of three ways:
/// - Build time, for development and the end-to-end journeys: both `--dart-define`s below set.
///   API: `--dart-define=API_BASE_URL=http://localhost:8081` (households), optionally
///   `TASKS_API_BASE_URL` (:8082), `SCORING_API_BASE_URL` (:8083), `LISTS_API_BASE_URL` (:8084) and
///   `NOTIFICATIONS_API_BASE_URL` (:8085), which default to API_BASE_URL. Sign-in:
///   `--dart-define=KEYCLOAK_ISSUER=http://localhost:8180/realms/betterhome`.
/// - At run time, when they are not set: the app asks for the server address on first launch
///   (T-0115, ADR 0029) and remembers it. This is what a published build does, with no host inside.
/// Either way `KEYCLOAK_CLIENT_ID` (default `betterhome-app`) names the client.
/// On the Android emulator use 10.0.2.2 for the API and run `adb reverse tcp:8180 tcp:8180`, because
/// Keycloak advertises `localhost:8180` in its discovery document.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  const tasksApiBaseUrl = String.fromEnvironment('TASKS_API_BASE_URL');
  const scoringApiBaseUrl = String.fromEnvironment('SCORING_API_BASE_URL');
  const listsApiBaseUrl = String.fromEnvironment('LISTS_API_BASE_URL');
  const notificationsApiBaseUrl = String.fromEnvironment(
    'NOTIFICATIONS_API_BASE_URL',
  );
  const keycloakIssuer = String.fromEnvironment('KEYCLOAK_ISSUER');
  const keycloakClientId = String.fromEnvironment(
    'KEYCLOAK_CLIENT_ID',
    defaultValue: 'betterhome-app',
  );

  if (apiBaseUrl.isEmpty || keycloakIssuer.isEmpty) {
    runApp(
      ServerApp(
        preferences: preferences,
        buildStack: (server) =>
            buildStackForServer(server, keycloakClientId, preferences),
      ),
    );
    return;
  }

  final stack = buildStackFromUrls(
    issuer: keycloakIssuer,
    clientId: keycloakClientId,
    householdsUrl: apiBaseUrl,
    tasksUrl: tasksApiBaseUrl.isEmpty ? apiBaseUrl : tasksApiBaseUrl,
    scoringUrl: scoringApiBaseUrl.isEmpty ? apiBaseUrl : scoringApiBaseUrl,
    listsUrl: listsApiBaseUrl.isEmpty ? apiBaseUrl : listsApiBaseUrl,
    notificationsUrl: notificationsApiBaseUrl.isEmpty
        ? apiBaseUrl
        : notificationsApiBaseUrl,
    preferences: preferences,
  );
  runApp(BetterHomeApp(auth: stack.auth, session: stack.session));
}
