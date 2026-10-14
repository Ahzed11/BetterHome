import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:flutter/foundation.dart';

class AppSession extends ChangeNotifier {
  AppSession({
    required HouseholdsRepository repository,
    TasksRepository? tasksRepository,
    ScoringRepository? scoringRepository,
  }) : _repository = repository,
       _tasksRepository = tasksRepository ?? FakeTasksRepository(),
       _scoringRepository = scoringRepository ?? FakeScoringRepository();

  HouseholdsRepository _repository;
  TasksRepository _tasksRepository;
  ScoringRepository _scoringRepository;
  UserProfile? profile;
  Object? lastError;
  bool busy = false;

  HouseholdsRepository get repository => _repository;
  TasksRepository get tasksRepository => _tasksRepository;
  ScoringRepository get scoringRepository => _scoringRepository;

  void useRepository(HouseholdsRepository repository) {
    _repository = repository;
    notifyListeners();
  }

  void useTasksRepository(TasksRepository repository) {
    _tasksRepository = repository;
    notifyListeners();
  }

  void useScoringRepository(ScoringRepository repository) {
    _scoringRepository = repository;
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
      if (_scoringRepository is FakeScoringRepository) {
        final fake = FakeScoringRepository(
          memberIds: [profile?.id ?? 'user-1', 'user-2'],
        );
        useScoringRepository(fake);
      }
      if (_tasksRepository is FakeTasksRepository) {
        final ledger = _scoringRepository;
        useTasksRepository(
          FakeTasksRepository(
            currentUserId: profile?.id ?? 'user-1',
            ledger: ledger is FakeScoringRepository ? ledger : null,
          ),
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
