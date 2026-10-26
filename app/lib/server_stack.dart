import 'package:betterhome/auth/auth_service.dart';
import 'package:betterhome/auth/oidc_auth_service.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/server_config.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app needs to talk to one server: how to sign in, and the session whose repositories
/// call it.
typedef ServerStack = ({AuthService auth, AppSession session});

/// Builds the stack for explicit URLs, one per service (the build-time settings used in
/// development and by the end-to-end journeys).
ServerStack buildStackFromUrls({
  required String issuer,
  required String clientId,
  required String householdsUrl,
  required String tasksUrl,
  required String scoringUrl,
  required String listsUrl,
  required String notificationsUrl,
  required SharedPreferences preferences,
}) {
  final auth = OidcAuthService.forPlatform(
    issuer: Uri.parse(issuer),
    clientId: clientId,
  );
  final session = AppSession(
    preferences: preferences,
    repository: HttpHouseholdsRepository(
      baseUrl: householdsUrl,
      accessToken: auth.accessToken,
    ),
    tasksRepository: HttpTasksRepository(
      baseUrl: tasksUrl,
      accessToken: auth.accessToken,
    ),
    scoringRepository: HttpScoringRepository(
      baseUrl: scoringUrl,
      accessToken: auth.accessToken,
    ),
    listsRepository: HttpListsRepository(
      baseUrl: listsUrl,
      accessToken: auth.accessToken,
    ),
    notificationsRepository: HttpNotificationsRepository(
      baseUrl: notificationsUrl,
      accessToken: auth.accessToken,
    ),
  );
  return (auth: auth, session: session);
}

/// Builds the stack for a server address entered in the app.
ServerStack buildStackForServer(
  ServerConfig server,
  String clientId,
  SharedPreferences preferences,
) => buildStackFromUrls(
  issuer: server.issuer,
  clientId: clientId,
  householdsUrl: server.householdsUrl,
  tasksUrl: server.tasksUrl,
  scoringUrl: server.scoringUrl,
  listsUrl: server.listsUrl,
  notificationsUrl: server.notificationsUrl,
  preferences: preferences,
);
