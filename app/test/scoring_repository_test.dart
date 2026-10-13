import 'package:betterhome/data/scoring_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake scoreboard ranks and effort shares', () async {
    final repo = FakeScoringRepository(memberIds: ['a', 'b']);
    await repo.award(
      householdId: 'hh',
      userId: 'a',
      taskId: 't1',
      points: 6,
      late: false,
    );
    await repo.award(
      householdId: 'hh',
      userId: 'b',
      taskId: 't2',
      points: 4,
      late: true,
    );

    final board = await repo.getScoreboard('hh', period: ScorePeriod.all);
    expect(board.totalPoints, 10);
    expect(board.podium.first.userId, 'a');
    expect(board.podium.first.points, 6);
    expect(board.entries.first.effortShare, closeTo(0.6, 0.001));
  });

  test('reverse lowers score without going below zero display', () async {
    final repo = FakeScoringRepository(memberIds: ['a']);
    await repo.award(
      householdId: 'hh',
      userId: 'a',
      taskId: 't1',
      points: 5,
      late: false,
    );
    await repo.reverse(
      householdId: 'hh',
      taskId: 't1',
      assigneeUserId: 'a',
      points: 5,
      reason: 'mistake',
      resultingStatus: 'reverted',
    );
    final board = await repo.getScoreboard('hh');
    expect(board.entries.single.points, 0);
  });
}
