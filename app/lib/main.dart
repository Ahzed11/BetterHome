import 'package:betterhome/app.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:flutter/material.dart';

/// Entry point. Defaults to in-memory demo repositories.
/// Households: `--dart-define=API_BASE_URL=...` + `ACCESS_TOKEN`
/// Tasks: `--dart-define=TASKS_API_BASE_URL=http://10.0.2.2:8082` (optional)
void main() {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  const tasksApiBaseUrl = String.fromEnvironment('TASKS_API_BASE_URL');
  const accessToken = String.fromEnvironment('ACCESS_TOKEN');

  final HouseholdsRepository households;
  final TasksRepository tasks;
  if (apiBaseUrl.isNotEmpty && accessToken.isNotEmpty) {
    households = HttpHouseholdsRepository(
      baseUrl: apiBaseUrl,
      accessToken: accessToken,
    );
    tasks = HttpTasksRepository(
      baseUrl: tasksApiBaseUrl.isEmpty ? apiBaseUrl : tasksApiBaseUrl,
      accessToken: accessToken,
    );
  } else {
    households = FakeHouseholdsRepository();
    tasks = FakeTasksRepository();
  }

  runApp(
    BetterHomeApp(
      session: AppSession(repository: households, tasksRepository: tasks),
    ),
  );
}
