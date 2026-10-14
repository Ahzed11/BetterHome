import 'package:betterhome/data/api_mappers.dart';
import 'package:betterhome/data/api_support.dart';
import 'package:betterhome_api/api.dart' as api;
import 'package:http/http.dart' as http;

enum ScorePeriod { week, month, year, all }

class ScoreEntry {
  const ScoreEntry({
    required this.userId,
    required this.points,
    required this.effortShare,
    required this.rank,
  });

  final String userId;
  final int points;
  final double effortShare;
  final int rank;
}

class Scoreboard {
  const Scoreboard({
    required this.period,
    this.yearMonth,
    required this.totalPoints,
    required this.entries,
    required this.podium,
  });

  final ScorePeriod period;
  final String? yearMonth;
  final int totalPoints;
  final List<ScoreEntry> entries;
  final List<ScoreEntry> podium;
}

class MonthlyWinner {
  const MonthlyWinner({
    required this.yearMonth,
    this.winnerUserId,
    required this.winnerPoints,
    required this.totalPoints,
    this.celebrated = false,
  });

  final String yearMonth;
  final String? winnerUserId;
  final int winnerPoints;
  final int totalPoints;

  /// Whether the signed-in user has already seen the confetti of this month.
  final bool celebrated;
}

abstract class ScoringRepository {
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  });

  Future<List<MonthlyWinner>> listWinners(String householdId);

  /// Records that the signed-in user has seen the recap of [yearMonth] (`YYYY-MM`).
  Future<void> markRecapCelebrated(String householdId, String yearMonth);
}

class HttpScoringRepository implements ScoringRepository {
  HttpScoringRepository({
    required String baseUrl,
    required String Function() accessToken,
    http.Client? client,
  }) : _scoreboard = api.ScoreboardApi(
         buildApiClient(
           baseUrl: baseUrl,
           accessToken: accessToken,
           client: client,
         ),
       );

  final api.ScoreboardApi _scoreboard;

  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) async {
    return scoreboardFromApi(
      await call(
        () => _scoreboard.getScoreboard(
          householdId,
          period: api.ScorePeriod.values.byName(period.name),
          yearMonth: yearMonth,
        ),
      ),
    );
  }

  @override
  Future<List<MonthlyWinner>> listWinners(String householdId) async {
    final list = await call(() => _scoreboard.listWinners(householdId));
    return list.map(monthlyWinnerFromApi).toList();
  }

  @override
  Future<void> markRecapCelebrated(String householdId, String yearMonth) async {
    await call(() => _scoreboard.markRecapCelebrated(householdId, yearMonth));
  }
}

class FakeScoringRepository implements ScoringRepository {
  FakeScoringRepository({List<String>? memberIds})
    : _memberIds = List<String>.from(memberIds ?? const ['user-1', 'user-2']);

  final List<String> _memberIds;
  final Map<String, List<_LedgerRow>> _ledger = {};
  final Map<String, List<MonthlyWinner>> _winners = {};
  final Set<String> _seenRecaps = {};

  void setMembers(List<String> memberIds) {
    _memberIds
      ..clear()
      ..addAll(memberIds);
  }

  /// Seeds podium/effort sample data once per household for demo mode.
  void seedDemoIfEmpty(String householdId) {
    if (_ledger.containsKey(householdId)) {
      return;
    }
    final primary = _memberIds.isNotEmpty ? _memberIds.first : 'user-1';
    final secondary = _memberIds.length > 1 ? _memberIds[1] : 'user-2';
    _ledger[householdId] = [
      _LedgerRow(userId: primary, points: 12, at: DateTime.utc(2026, 10, 1)),
      _LedgerRow(userId: secondary, points: 8, at: DateTime.utc(2026, 10, 2)),
      _LedgerRow(userId: primary, points: 5, at: DateTime.utc(2026, 10, 5)),
    ];
    _winners[householdId] = [
      MonthlyWinner(
        yearMonth: '2026-09',
        winnerUserId: secondary,
        winnerPoints: 20,
        totalPoints: 35,
      ),
    ];
  }

  Future<void> award({
    required String householdId,
    required String userId,
    required String taskId,
    required int points,
    required bool late,
  }) async {
    _ledger
        .putIfAbsent(householdId, () => [])
        .add(
          _LedgerRow(
            userId: userId,
            points: points,
            at: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> reverse({
    required String householdId,
    required String taskId,
    required String assigneeUserId,
    required int points,
    required String reason,
    required String resultingStatus,
  }) async {
    _ledger
        .putIfAbsent(householdId, () => [])
        .add(
          _LedgerRow(
            userId: assigneeUserId,
            points: -points,
            at: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) async {
    final rows = _ledger[householdId] ?? const <_LedgerRow>[];
    final sums = <String, int>{for (final id in _memberIds) id: 0};
    for (final row in rows) {
      sums[row.userId] = (sums[row.userId] ?? 0) + row.points;
    }
    final raw =
        sums.entries
            .map((e) => MapEntry(e.key, e.value < 0 ? 0 : e.value))
            .toList()
          ..sort((a, b) {
            final byPoints = b.value.compareTo(a.value);
            return byPoints != 0 ? byPoints : a.key.compareTo(b.key);
          });
    final total = raw.fold<int>(0, (sum, e) => sum + e.value);
    final entries = <ScoreEntry>[];
    var rank = 0;
    var last = -1;
    for (var i = 0; i < raw.length; i++) {
      final points = raw[i].value;
      if (points != last) {
        rank = i + 1;
        last = points;
      }
      entries.add(
        ScoreEntry(
          userId: raw[i].key,
          points: points,
          effortShare: total == 0 ? 0 : points / total,
          rank: rank,
        ),
      );
    }
    return Scoreboard(
      period: period,
      yearMonth: yearMonth,
      totalPoints: total,
      entries: entries,
      podium: entries.where((e) => e.rank <= 3).take(3).toList(),
    );
  }

  @override
  Future<List<MonthlyWinner>> listWinners(String householdId) async => [
    for (final winner in _winners[householdId] ?? const <MonthlyWinner>[])
      MonthlyWinner(
        yearMonth: winner.yearMonth,
        winnerUserId: winner.winnerUserId,
        winnerPoints: winner.winnerPoints,
        totalPoints: winner.totalPoints,
        celebrated: _seenRecaps.contains('$householdId|${winner.yearMonth}'),
      ),
  ];

  @override
  Future<void> markRecapCelebrated(String householdId, String yearMonth) async {
    _seenRecaps.add('$householdId|$yearMonth');
  }
}

class _LedgerRow {
  const _LedgerRow({
    required this.userId,
    required this.points,
    required this.at,
  });

  final String userId;
  final int points;
  final DateTime at;
}
