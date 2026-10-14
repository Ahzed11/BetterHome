import 'dart:async';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';

/// Households repository whose reads never complete (loading state).
class PendingHouseholdsRepository extends FakeHouseholdsRepository {
  @override
  Future<List<Household>> listHouseholds() =>
      Completer<List<Household>>().future;

  @override
  Future<Household> getHousehold(String householdId) =>
      Completer<Household>().future;
}

/// Households repository whose reads fail (error state).
class FailingHouseholdsRepository extends FakeHouseholdsRepository {
  @override
  Future<List<Household>> listHouseholds() async =>
      throw ApiException('boom', statusCode: 500);

  @override
  Future<Household> getHousehold(String householdId) async =>
      throw ApiException('boom', statusCode: 500);
}

/// Households repository whose creation is rejected (form error state).
class RejectingHouseholdsRepository extends FakeHouseholdsRepository {
  @override
  Future<Household> createHousehold({
    required String name,
    required String timezone,
  }) async => throw ApiException('invalid', statusCode: 400);
}

/// Tasks repository whose list never completes (loading state).
class PendingTasksRepository extends FakeTasksRepository {
  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) => Completer<List<ChoreTask>>().future;
}

/// Tasks repository whose list fails (error state).
class FailingTasksRepository extends FakeTasksRepository {
  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) async => throw ApiException('boom', statusCode: 500);
}

/// Scoring repository with no points and no winners yet (empty state).
class EmptyScoringRepository extends FakeScoringRepository {
  @override
  void seedDemoIfEmpty(String householdId) {}

  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) async => Scoreboard(
    period: period,
    totalPoints: 0,
    entries: const [],
    podium: const [],
  );
}

/// Scoring repository whose reads never complete (loading state).
class PendingScoringRepository extends FakeScoringRepository {
  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) => Completer<Scoreboard>().future;
}

/// Scoring repository whose reads fail (error state).
class FailingScoringRepository extends FakeScoringRepository {
  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) async => throw ApiException('boom', statusCode: 500);
}

/// Lists repository whose reads never complete (loading state).
class PendingListsRepository extends FakeListsRepository {
  @override
  Future<List<Checklist>> listLists(String householdId) =>
      Completer<List<Checklist>>().future;

  @override
  Future<List<ChecklistItem>> listItems(String householdId, String listId) =>
      Completer<List<ChecklistItem>>().future;
}

/// Lists repository whose reads fail (error state).
class FailingListsRepository extends FakeListsRepository {
  @override
  Future<List<Checklist>> listLists(String householdId) async =>
      throw ApiException('boom', statusCode: 500);

  @override
  Future<List<ChecklistItem>> listItems(
    String householdId,
    String listId,
  ) async => throw ApiException('boom', statusCode: 500);
}
