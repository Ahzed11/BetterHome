import 'package:betterhome/app.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:flutter/material.dart';

/// Entry point. Defaults to in-memory demo repositories.
/// Households: `--dart-define=API_BASE_URL=...` + `ACCESS_TOKEN`
/// Tasks: `--dart-define=TASKS_API_BASE_URL=http://10.0.2.2:8082` (optional)
/// Scoring: `--dart-define=SCORING_API_BASE_URL=http://10.0.2.2:8083` (optional)
void main() {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  const tasksApiBaseUrl = String.fromEnvironment('TASKS_API_BASE_URL');
  const scoringApiBaseUrl = String.fromEnvironment('SCORING_API_BASE_URL');
  const accessToken = String.fromEnvironment('ACCESS_TOKEN');

  final HouseholdsRepository households;
  final TasksRepository tasks;
  final ScoringRepository scoring;
  if (apiBaseUrl.isNotEmpty && accessToken.isNotEmpty) {
    households = HttpHouseholdsRepository(
      baseUrl: apiBaseUrl,
      accessToken: accessToken,
    );
    tasks = HttpTasksRepository(
      baseUrl: tasksApiBaseUrl.isEmpty ? apiBaseUrl : tasksApiBaseUrl,
      accessToken: accessToken,
    );
    scoring = HttpScoringRepository(
      baseUrl: scoringApiBaseUrl.isEmpty ? apiBaseUrl : scoringApiBaseUrl,
      accessToken: accessToken,
    );
  } else {
    households = FakeHouseholdsRepository();
    tasks = FakeTasksRepository();
    final fakeScoring = FakeScoringRepository();
    scoring = fakeScoring;
  }

  runApp(
    BetterHomeApp(
      session: AppSession(
        repository: households,
        tasksRepository: tasks,
        scoringRepository: scoring,
      ),
    ),
  );
}
