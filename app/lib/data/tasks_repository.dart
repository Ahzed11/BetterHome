import 'dart:convert';

import 'package:betterhome/data/models.dart';
import 'package:http/http.dart' as http;

enum TaskStatus { open, done, dismissed, reverted }

enum TaskOrigin {
  manual,
  adHoc,
  recurrence;

  static TaskOrigin fromApi(String value) {
    return switch (value) {
      'manual' => TaskOrigin.manual,
      'ad_hoc' => TaskOrigin.adHoc,
      'recurrence' => TaskOrigin.recurrence,
      _ => throw FormatException('Unknown task origin: $value'),
    };
  }
}

class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.householdId,
    required this.title,
    this.emoji,
    required this.description,
    required this.points,
    required this.latePoints,
    required this.defaultDueOffsetMinutes,
  });

  final String id;
  final String householdId;
  final String title;
  final String? emoji;
  final String description;
  final int points;
  final int latePoints;
  final int defaultDueOffsetMinutes;

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'] as String,
      householdId: json['householdId'] as String,
      title: json['title'] as String,
      emoji: json['emoji'] as String?,
      description: json['description'] as String? ?? '',
      points: json['points'] as int,
      latePoints: json['latePoints'] as int,
      defaultDueOffsetMinutes: json['defaultDueOffsetMinutes'] as int? ?? 1440,
    );
  }
}

class ChoreTask {
  const ChoreTask({
    required this.id,
    required this.householdId,
    required this.templateId,
    required this.origin,
    required this.title,
    this.emoji,
    required this.points,
    required this.latePoints,
    required this.status,
    required this.assigneeId,
    this.dueAt,
    this.completedAt,
    this.pointsAwarded,
  });

  final String id;
  final String householdId;
  final String templateId;
  final TaskOrigin origin;
  final String title;
  final String? emoji;
  final int points;
  final int latePoints;
  final TaskStatus status;
  final String assigneeId;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final int? pointsAwarded;

  factory ChoreTask.fromJson(Map<String, dynamic> json) {
    return ChoreTask(
      id: json['id'] as String,
      householdId: json['householdId'] as String,
      templateId: json['templateId'] as String,
      origin: TaskOrigin.fromApi(json['origin'] as String),
      title: json['title'] as String,
      emoji: json['emoji'] as String?,
      points: json['points'] as int,
      latePoints: json['latePoints'] as int,
      status: TaskStatus.values.byName(json['status'] as String),
      assigneeId: json['assigneeId'] as String,
      dueAt: json['dueAt'] == null
          ? null
          : DateTime.parse(json['dueAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      pointsAwarded: json['pointsAwarded'] as int?,
    );
  }
}

enum AssignmentMode { fixed, roundRobin }

class TaskRecurrence {
  const TaskRecurrence({
    required this.id,
    required this.householdId,
    required this.templateId,
    required this.rrule,
    required this.assignmentMode,
    this.fixedAssigneeId,
    required this.timezone,
    required this.startsAt,
    this.endsAt,
    this.lastGeneratedAt,
    this.nextRunAt,
  });

  final String id;
  final String householdId;
  final String templateId;
  final String rrule;
  final AssignmentMode assignmentMode;
  final String? fixedAssigneeId;
  final String timezone;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime? lastGeneratedAt;
  final DateTime? nextRunAt;

  factory TaskRecurrence.fromJson(Map<String, dynamic> json) {
    final mode = json['assignmentMode'] as String;
    return TaskRecurrence(
      id: json['id'] as String,
      householdId: json['householdId'] as String,
      templateId: json['templateId'] as String,
      rrule: json['rrule'] as String,
      assignmentMode: mode == 'fixed'
          ? AssignmentMode.fixed
          : AssignmentMode.roundRobin,
      fixedAssigneeId: json['fixedAssigneeId'] as String?,
      timezone: json['timezone'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: json['endsAt'] == null
          ? null
          : DateTime.parse(json['endsAt'] as String),
      lastGeneratedAt: json['lastGeneratedAt'] == null
          ? null
          : DateTime.parse(json['lastGeneratedAt'] as String),
      nextRunAt: json['nextRunAt'] == null
          ? null
          : DateTime.parse(json['nextRunAt'] as String),
    );
  }
}

abstract class TasksRepository {
  Future<List<TaskTemplate>> listTemplates(String householdId);

  Future<TaskTemplate> createTemplate({
    required String householdId,
    required String title,
    String? emoji,
    String description,
    required int points,
    required int latePoints,
  });

  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  });

  Future<ChoreTask> quickLog({
    required String householdId,
    required String templateId,
  });

  Future<ChoreTask> createOpen({
    required String householdId,
    required String templateId,
  });

  Future<ChoreTask> complete(String householdId, String taskId);

  Future<ChoreTask> dismiss(String householdId, String taskId);

  Future<ChoreTask> reassign(String householdId, String taskId);

  Future<ChoreTask> revert(
    String householdId,
    String taskId, {
    required String reason,
  });

  Future<TaskRecurrence?> getRecurrence(String householdId, String templateId);

  Future<TaskRecurrence> upsertRecurrence({
    required String householdId,
    required String templateId,
    required String rrule,
    required AssignmentMode assignmentMode,
    String? fixedAssigneeId,
    DateTime? startsAt,
  });

  /// Demo/ops: process due recurrences (fake) or no-op for HTTP (scheduler owns it).
  Future<int> runDueRecurrences(String householdId);
}

class HttpTasksRepository implements TasksRepository {
  HttpTasksRepository({
    required this.baseUrl,
    required this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String accessToken;
  final http.Client _client;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _json(http.Response response) async {
    if (response.statusCode >= 400) {
      throw ApiException(response.body, statusCode: response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _jsonList(http.Response response) async {
    if (response.statusCode >= 400) {
      throw ApiException(response.body, statusCode: response.statusCode);
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  @override
  Future<List<TaskTemplate>> listTemplates(String householdId) async {
    final response = await _client.get(
      _uri('/v1/households/$householdId/templates'),
      headers: _headers,
    );
    return (await _jsonList(
      response,
    )).map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<TaskTemplate> createTemplate({
    required String householdId,
    required String title,
    String? emoji,
    String description = '',
    required int points,
    required int latePoints,
  }) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/templates'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'emoji': emoji,
        'description': description,
        'points': points,
        'latePoints': latePoints,
      }),
    );
    return TaskTemplate.fromJson(await _json(response));
  }

  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) async {
    final query = <String, String>{'mine': '$mine'};
    if (status != null) {
      query['status'] = status.name;
    }
    final response = await _client.get(
      _uri('/v1/households/$householdId/tasks').replace(queryParameters: query),
      headers: _headers,
    );
    return (await _jsonList(
      response,
    )).map((e) => ChoreTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ChoreTask> quickLog({
    required String householdId,
    required String templateId,
  }) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/tasks/manual'),
      headers: _headers,
      body: jsonEncode({'templateId': templateId}),
    );
    return ChoreTask.fromJson(await _json(response));
  }

  @override
  Future<ChoreTask> createOpen({
    required String householdId,
    required String templateId,
  }) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/tasks'),
      headers: _headers,
      body: jsonEncode({'templateId': templateId}),
    );
    return ChoreTask.fromJson(await _json(response));
  }

  @override
  Future<ChoreTask> complete(String householdId, String taskId) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/tasks/$taskId/complete'),
      headers: _headers,
    );
    return ChoreTask.fromJson(await _json(response));
  }

  @override
  Future<ChoreTask> dismiss(String householdId, String taskId) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/tasks/$taskId/dismiss'),
      headers: _headers,
    );
    return ChoreTask.fromJson(await _json(response));
  }

  @override
  Future<ChoreTask> reassign(String householdId, String taskId) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/tasks/$taskId/reassign'),
      headers: _headers,
    );
    return ChoreTask.fromJson(await _json(response));
  }

  @override
  Future<ChoreTask> revert(
    String householdId,
    String taskId, {
    required String reason,
  }) async {
    final response = await _client.post(
      _uri('/v1/households/$householdId/tasks/$taskId/revert'),
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    return ChoreTask.fromJson(await _json(response));
  }

  @override
  Future<TaskRecurrence?> getRecurrence(
    String householdId,
    String templateId,
  ) async {
    final response = await _client.get(
      _uri('/v1/households/$householdId/templates/$templateId/recurrence'),
      headers: _headers,
    );
    if (response.statusCode == 404) {
      return null;
    }
    return TaskRecurrence.fromJson(await _json(response));
  }

  @override
  Future<TaskRecurrence> upsertRecurrence({
    required String householdId,
    required String templateId,
    required String rrule,
    required AssignmentMode assignmentMode,
    String? fixedAssigneeId,
    DateTime? startsAt,
  }) async {
    final response = await _client.put(
      _uri('/v1/households/$householdId/templates/$templateId/recurrence'),
      headers: _headers,
      body: jsonEncode({
        'rrule': rrule,
        'assignmentMode': assignmentMode == AssignmentMode.fixed
            ? 'fixed'
            : 'round_robin',
        'fixedAssigneeId': fixedAssigneeId,
        'startsAt': (startsAt ?? DateTime.now().toUtc()).toIso8601String(),
      }),
    );
    return TaskRecurrence.fromJson(await _json(response));
  }

  @override
  Future<int> runDueRecurrences(String householdId) async {
    return 0;
  }
}

class FakeTasksRepository implements TasksRepository {
  FakeTasksRepository({this.currentUserId = 'user-1'});

  final String currentUserId;
  final Map<String, List<TaskTemplate>> _templates = {};
  final Map<String, List<ChoreTask>> _tasks = {};
  final Map<String, TaskRecurrence> _recurrences = {};

  @override
  Future<List<TaskTemplate>> listTemplates(String householdId) async =>
      List.unmodifiable(_templates[householdId] ?? const []);

  @override
  Future<TaskTemplate> createTemplate({
    required String householdId,
    required String title,
    String? emoji,
    String description = '',
    required int points,
    required int latePoints,
  }) async {
    final template = TaskTemplate(
      id: 'tpl-${(_templates[householdId]?.length ?? 0) + 1}',
      householdId: householdId,
      title: title,
      emoji: emoji,
      description: description,
      points: points,
      latePoints: latePoints,
      defaultDueOffsetMinutes: 1440,
    );
    _templates.putIfAbsent(householdId, () => []).add(template);
    return template;
  }

  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) async {
    var tasks = _tasks[householdId] ?? const <ChoreTask>[];
    if (status != null) {
      tasks = tasks.where((t) => t.status == status).toList();
    }
    if (mine) {
      tasks = tasks.where((t) => t.assigneeId == currentUserId).toList();
    }
    return List.unmodifiable(tasks);
  }

  @override
  Future<ChoreTask> quickLog({
    required String householdId,
    required String templateId,
  }) async {
    final template = (await listTemplates(
      householdId,
    )).firstWhere((t) => t.id == templateId);
    final task = ChoreTask(
      id: 'task-${DateTime.now().microsecondsSinceEpoch}',
      householdId: householdId,
      templateId: template.id,
      origin: TaskOrigin.manual,
      title: template.title,
      emoji: template.emoji,
      points: template.points,
      latePoints: template.latePoints,
      status: TaskStatus.done,
      assigneeId: currentUserId,
      completedAt: DateTime.now().toUtc(),
      pointsAwarded: template.points,
    );
    _tasks.putIfAbsent(householdId, () => []).add(task);
    return task;
  }

  @override
  Future<ChoreTask> createOpen({
    required String householdId,
    required String templateId,
  }) async {
    final template = (await listTemplates(
      householdId,
    )).firstWhere((t) => t.id == templateId);
    final task = ChoreTask(
      id: 'task-${DateTime.now().microsecondsSinceEpoch}',
      householdId: householdId,
      templateId: template.id,
      origin: TaskOrigin.adHoc,
      title: template.title,
      emoji: template.emoji,
      points: template.points,
      latePoints: template.latePoints,
      status: TaskStatus.open,
      assigneeId: currentUserId,
      dueAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    _tasks.putIfAbsent(householdId, () => []).add(task);
    return task;
  }

  @override
  Future<ChoreTask> complete(String householdId, String taskId) async {
    return _replace(
      householdId,
      taskId,
      (t) => ChoreTask(
        id: t.id,
        householdId: t.householdId,
        templateId: t.templateId,
        origin: t.origin,
        title: t.title,
        emoji: t.emoji,
        points: t.points,
        latePoints: t.latePoints,
        status: TaskStatus.done,
        assigneeId: t.assigneeId,
        dueAt: t.dueAt,
        completedAt: DateTime.now().toUtc(),
        pointsAwarded: t.points,
      ),
    );
  }

  @override
  Future<ChoreTask> dismiss(String householdId, String taskId) async {
    return _replace(
      householdId,
      taskId,
      (t) => ChoreTask(
        id: t.id,
        householdId: t.householdId,
        templateId: t.templateId,
        origin: t.origin,
        title: t.title,
        emoji: t.emoji,
        points: t.points,
        latePoints: t.latePoints,
        status: TaskStatus.dismissed,
        assigneeId: t.assigneeId,
        dueAt: t.dueAt,
      ),
    );
  }

  @override
  Future<ChoreTask> reassign(String householdId, String taskId) async {
    return _replace(
      householdId,
      taskId,
      (t) => ChoreTask(
        id: t.id,
        householdId: t.householdId,
        templateId: t.templateId,
        origin: t.origin,
        title: t.title,
        emoji: t.emoji,
        points: t.points,
        latePoints: t.latePoints,
        status: t.status,
        assigneeId: 'user-2',
        dueAt: t.dueAt,
        completedAt: t.completedAt,
        pointsAwarded: t.pointsAwarded,
      ),
    );
  }

  @override
  Future<ChoreTask> revert(
    String householdId,
    String taskId, {
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ApiException('reason required', statusCode: 400);
    }
    return _replace(householdId, taskId, (t) {
      if (t.status != TaskStatus.done) {
        throw ApiException('only done', statusCode: 409);
      }
      final resulting = t.origin == TaskOrigin.manual
          ? TaskStatus.reverted
          : (t.dueAt != null && t.dueAt!.isAfter(DateTime.now().toUtc())
                ? TaskStatus.open
                : TaskStatus.dismissed);
      return ChoreTask(
        id: t.id,
        householdId: t.householdId,
        templateId: t.templateId,
        origin: t.origin,
        title: t.title,
        emoji: t.emoji,
        points: t.points,
        latePoints: t.latePoints,
        status: resulting,
        assigneeId: t.assigneeId,
        dueAt: t.dueAt,
      );
    });
  }

  @override
  Future<TaskRecurrence?> getRecurrence(
    String householdId,
    String templateId,
  ) async => _recurrences['$householdId|$templateId'];

  @override
  Future<TaskRecurrence> upsertRecurrence({
    required String householdId,
    required String templateId,
    required String rrule,
    required AssignmentMode assignmentMode,
    String? fixedAssigneeId,
    DateTime? startsAt,
  }) async {
    final key = '$householdId|$templateId';
    final recurrence = TaskRecurrence(
      id: 'rec-${_recurrences.length + 1}',
      householdId: householdId,
      templateId: templateId,
      rrule: rrule,
      assignmentMode: assignmentMode,
      fixedAssigneeId: fixedAssigneeId,
      timezone: 'UTC',
      startsAt: startsAt ?? DateTime.now().toUtc(),
      nextRunAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    _recurrences[key] = recurrence;
    return recurrence;
  }

  @override
  Future<int> runDueRecurrences(String householdId) async {
    var spawned = 0;
    final due = _recurrences.values
        .where(
          (r) =>
              r.householdId == householdId &&
              r.nextRunAt != null &&
              !r.nextRunAt!.isAfter(DateTime.now().toUtc()),
        )
        .toList();
    for (final recurrence in due) {
      final templates = _templates[householdId] ?? const <TaskTemplate>[];
      final matches = templates.where((t) => t.id == recurrence.templateId);
      if (matches.isEmpty) {
        continue;
      }
      final template = matches.first;
      final tasks = _tasks.putIfAbsent(householdId, () => []);
      for (var i = 0; i < tasks.length; i++) {
        final t = tasks[i];
        if (t.templateId == template.id &&
            t.origin == TaskOrigin.recurrence &&
            t.status == TaskStatus.open) {
          tasks[i] = ChoreTask(
            id: t.id,
            householdId: t.householdId,
            templateId: t.templateId,
            origin: t.origin,
            title: t.title,
            emoji: t.emoji,
            points: t.points,
            latePoints: t.latePoints,
            status: TaskStatus.dismissed,
            assigneeId: t.assigneeId,
            dueAt: t.dueAt,
          );
        }
      }
      final task = ChoreTask(
        id: 'task-${DateTime.now().microsecondsSinceEpoch}-$spawned',
        householdId: householdId,
        templateId: template.id,
        origin: TaskOrigin.recurrence,
        title: template.title,
        emoji: template.emoji,
        points: template.points,
        latePoints: template.latePoints,
        status: TaskStatus.open,
        assigneeId: currentUserId,
        dueAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      tasks.add(task);
      _recurrences['$householdId|${template.id}'] = TaskRecurrence(
        id: recurrence.id,
        householdId: recurrence.householdId,
        templateId: recurrence.templateId,
        rrule: recurrence.rrule,
        assignmentMode: recurrence.assignmentMode,
        fixedAssigneeId: recurrence.fixedAssigneeId,
        timezone: recurrence.timezone,
        startsAt: recurrence.startsAt,
        endsAt: recurrence.endsAt,
        lastGeneratedAt: DateTime.now().toUtc(),
        nextRunAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      spawned++;
    }
    return spawned;
  }

  ChoreTask _replace(
    String householdId,
    String taskId,
    ChoreTask Function(ChoreTask) map,
  ) {
    final list = _tasks[householdId] ?? [];
    final index = list.indexWhere((t) => t.id == taskId);
    if (index < 0) {
      throw ApiException('not found', statusCode: 404);
    }
    final updated = map(list[index]);
    list[index] = updated;
    return updated;
  }
}
