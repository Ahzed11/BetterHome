import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:flutter/foundation.dart';

class AppSession extends ChangeNotifier {
  AppSession({required HouseholdsRepository repository})
    : _repository = repository;

  HouseholdsRepository _repository;
  UserProfile? profile;
  Object? lastError;
  bool busy = false;

  HouseholdsRepository get repository => _repository;

  void useRepository(HouseholdsRepository repository) {
    _repository = repository;
    notifyListeners();
  }

  Future<void> syncProfile({
    required String email,
    String? givenName,
    String? familyName,
    String language = 'en',
    String timezone = 'UTC',
  }) async {
    await _run(() async {
      profile = await _repository.syncMe(
        email: email,
        givenName: givenName,
        familyName: familyName,
        language: language,
        timezone: timezone,
      );
    });
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final result = await action();
      return result;
    } catch (error) {
      lastError = error;
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
