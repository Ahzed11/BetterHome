import 'dart:convert';

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

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      userId: json['userId'] as String,
      points: json['points'] as int,
      effortShare: (json['effortShare'] as num).toDouble(),
      rank: json['rank'] as int,
    );
  }
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

  factory Scoreboard.fromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as List<dynamic>)
        .map((e) => ScoreEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    final podium = (json['podium'] as List<dynamic>)
        .map((e) => ScoreEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return Scoreboard(
      period: ScorePeriod.values.byName(json['period'] as String),
      yearMonth: json['yearMonth'] as String?,
      totalPoints: json['totalPoints'] as int,
      entries: entries,
      podium: podium,
    );
  }
}

class MonthlyWinner {
  const MonthlyWinner({
    required this.yearMonth,
    this.winnerUserId,
    required this.winnerPoints,
    required this.totalPoints,
  });

  final String yearMonth;
  final String? winnerUserId;
  final int winnerPoints;
  final int totalPoints;

  factory MonthlyWinner.fromJson(Map<String, dynamic> json) {
    return MonthlyWinner(
      yearMonth: json['yearMonth'] as String,
      winnerUserId: json['winnerUserId'] as String?,
      winnerPoints: json['winnerPoints'] as int,
      totalPoints: json['totalPoints'] as int,
    );
  }
}

abstract class ScoringRepository {
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  });

  Future<List<MonthlyWinner>> listWinners(String householdId);

  Future<void> award({
    required String householdId,
    required String userId,
    required String taskId,
    required int points,
    required bool late,
  });

  Future<void> reverse({
    required String householdId,
    required String taskId,
    required String assigneeUserId,
    required int points,
    required String reason,
    required String resultingStatus,
  });
}

class HttpScoringRepository implements ScoringRepository {
  HttpScoringRepository({
    required this.baseUrl,
    required this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String accessToken;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> _json(http.Response response) async {
    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    if (response.body.isEmpty) {
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) async {
    final query = <String, String>{'period': period.name};
    if (yearMonth != null) {
      query['yearMonth'] = yearMonth;
    }
    final response = await _client.get(
      _uri('/v1/households/$householdId/scoreboard', query),
      headers: _headers,
    );
    return Scoreboard.fromJson(await _json(response));
  }

  @override
  Future<List<MonthlyWinner>> listWinners(String householdId) async {
    final response = await _client.get(
      _uri('/v1/households/$householdId/scoreboard/winners'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => MonthlyWinner.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> award({
    required String householdId,
    required String userId,
    required String taskId,
    required int points,
    required bool late,
  }) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/points/award'),
      headers: _headers,
      body: jsonEncode({
        'userId': userId,
        'taskId': taskId,
        'points': points,
        'reason': late ? 'task_completed_late' : 'task_completed',
      }),
    );
    await _json(response);
  }

  @override
  Future<void> reverse({
    required String householdId,
    required String taskId,
    required String assigneeUserId,
    required int points,
    required String reason,
    required String resultingStatus,
  }) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/points/reverse'),
      headers: _headers,
      body: jsonEncode({
        'taskId': taskId,
        'assigneeUserId': assigneeUserId,
        'points': points,
        'reason': reason,
        'resultingStatus': resultingStatus,
      }),
    );
    await _json(response);
  }
}

class FakeScoringRepository implements ScoringRepository {
  FakeScoringRepository({List<String>? memberIds})
    : _memberIds = List<String>.from(memberIds ?? const ['user-1', 'user-2']);

  final List<String> _memberIds;
  final Map<String, List<_LedgerRow>> _ledger = {};
  final Map<String, List<MonthlyWinner>> _winners = {};

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

  @override
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

  @override
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
  Future<List<MonthlyWinner>> listWinners(String householdId) async =>
      List.unmodifiable(_winners[householdId] ?? const []);
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
