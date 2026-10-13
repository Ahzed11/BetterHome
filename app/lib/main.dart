import 'package:betterhome/app.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:flutter/material.dart';

/// Entry point. Defaults to the in-memory demo repository.
/// Pass `--dart-define=API_BASE_URL=http://10.0.2.2:8081` and
/// `--dart-define=ACCESS_TOKEN=...` to hit a real households-service.
void main() {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  const accessToken = String.fromEnvironment('ACCESS_TOKEN');

  final HouseholdsRepository repository;
  if (apiBaseUrl.isNotEmpty && accessToken.isNotEmpty) {
    repository = HttpHouseholdsRepository(
      baseUrl: apiBaseUrl,
      accessToken: accessToken,
    );
  } else {
    repository = FakeHouseholdsRepository();
  }

  runApp(BetterHomeApp(session: AppSession(repository: repository)));
}
