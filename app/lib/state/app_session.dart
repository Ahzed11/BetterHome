import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:flutter/foundation.dart';

class AppSession extends ChangeNotifier {
  AppSession({
    required HouseholdsRepository repository,
    TasksRepository? tasksRepository,
    ScoringRepository? scoringRepository,
    ListsRepository? listsRepository,
    NotificationsRepository? notificationsRepository,
  }) : _repository = repository,
       _tasksRepository = tasksRepository ?? FakeTasksRepository(),
       _scoringRepository = scoringRepository ?? FakeScoringRepository(),
       _listsRepository = listsRepository ?? FakeListsRepository(),
       _notificationsRepository =
           notificationsRepository ?? FakeNotificationsRepository();

  HouseholdsRepository _repository;
  TasksRepository _tasksRepository;
  ScoringRepository _scoringRepository;
  ListsRepository _listsRepository;
  NotificationsRepository _notificationsRepository;
  UserProfile? profile;
  Object? lastError;
  bool busy = false;

  HouseholdsRepository get repository => _repository;
  TasksRepository get tasksRepository => _tasksRepository;
  ScoringRepository get scoringRepository => _scoringRepository;
  ListsRepository get listsRepository => _listsRepository;
  NotificationsRepository get notificationsRepository =>
      _notificationsRepository;

  void useRepository(HouseholdsRepository repository) {
    _repository = repository;
    notifyListeners();
  }

  void useTasksRepository(TasksRepository repository) {
    _tasksRepository = repository;
    notifyListeners();
  }

  void useListsRepository(ListsRepository repository) {
    _listsRepository = repository;
    notifyListeners();
  }

  void useNotificationsRepository(NotificationsRepository repository) {
    _notificationsRepository = repository;
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

  /// Loads the profile of a signed-in user. The profile is created from the identity provider's
  /// claims on the first sign-in only, so later sign-ins never overwrite what the user saved.
  Future<void> loadProfile({
    required String email,
    String? givenName,
    String? familyName,
    String language = 'en',
  }) async {
    await _run(() async {
      try {
        profile = await _repository.getMe();
      } on ApiException catch (e) {
        if (e.statusCode != 404) {
          rethrow;
        }
        profile = await _repository.syncMe(
          email: email,
          givenName: givenName,
          familyName: familyName,
          language: language,
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
