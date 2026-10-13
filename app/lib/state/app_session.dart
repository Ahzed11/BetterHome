import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:flutter/foundation.dart';

class AppSession extends ChangeNotifier {
  AppSession({
    required HouseholdsRepository repository,
    TasksRepository? tasksRepository,
  }) : _repository = repository,
       _tasksRepository = tasksRepository ?? FakeTasksRepository();

  HouseholdsRepository _repository;
  TasksRepository _tasksRepository;
  UserProfile? profile;
  Object? lastError;
  bool busy = false;

  HouseholdsRepository get repository => _repository;
  TasksRepository get tasksRepository => _tasksRepository;

  void useRepository(HouseholdsRepository repository) {
    _repository = repository;
    notifyListeners();
  }

  void useTasksRepository(TasksRepository repository) {
    _tasksRepository = repository;
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
      if (_tasksRepository is FakeTasksRepository) {
        useTasksRepository(
          FakeTasksRepository(currentUserId: profile?.id ?? 'user-1'),
        );
      }
    });
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      lastError = error;
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
