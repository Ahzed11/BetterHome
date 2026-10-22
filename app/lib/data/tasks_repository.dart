import 'package:betterhome/data/api_mappers.dart';
import 'package:betterhome/data/api_support.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome_api/api.dart' as api;
import 'package:http/http.dart' as http;

enum TaskStatus { open, done, dismissed, reverted }

enum TaskOrigin { manual, adHoc, recurrence }

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
    this.reversionReason,
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

  /// Why an admin reverted the task the last time, shown to the assignee.
  final String? reversionReason;
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

  /// Replaces the editable fields of a template; tasks already created keep their snapshot.
  Future<TaskTemplate> updateTemplate({
    required String householdId,
    required String templateId,
    required String title,
    required String emoji,
    required String description,
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
    DateTime? dueAt,
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
    required String baseUrl,
    required String Function() accessToken,
    http.Client? client,
  }) : _client = buildApiClient(
         baseUrl: baseUrl,
         accessToken: accessToken,
         client: client,
       );

  final api.ApiClient _client;

  api.TemplatesApi get _templates => api.TemplatesApi(_client);
  api.TasksApi get _tasks => api.TasksApi(_client);
  api.RecurrenceApi get _recurrence => api.RecurrenceApi(_client);

  @override
  Future<List<TaskTemplate>> listTemplates(String householdId) async {
    final list = await call(() => _templates.listTemplates(householdId));
    return list.map(taskTemplateFromApi).toList();
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
    return taskTemplateFromApi(
      await call(
        () => _templates.createTemplate(
          householdId,
          api.CreateTemplateRequest(
            title: title,
            emoji: emoji,
            description: description,
            points: points,
            latePoints: latePoints,
          ),
        ),
      ),
    );
  }

  @override
  Future<TaskTemplate> updateTemplate({
    required String householdId,
    required String templateId,
    required String title,
    required String emoji,
    required String description,
    required int points,
    required int latePoints,
  }) async {
    return taskTemplateFromApi(
      await call(
        () => _templates.updateTemplate(
          householdId,
          templateId,
          api.UpdateTemplateRequest(
            title: title,
            emoji: emoji,
            description: description,
            points: points,
            latePoints: latePoints,
          ),
        ),
      ),
    );
  }

  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) async {
    final list = await call(
      () => _tasks.listTasks(
        householdId,
        mine: mine,
        status: status == null
            ? null
            : api.TaskStatus.values.byName(status.name),
      ),
    );
    return list.map(choreTaskFromApi).toList();
  }

  @override
  Future<ChoreTask> quickLog({
    required String householdId,
    required String templateId,
  }) async {
    return choreTaskFromApi(
      await call(
        () => _tasks.quickLogTask(
          householdId,
          api.QuickLogRequest(templateId: templateId),
        ),
      ),
    );
  }

  @override
  Future<ChoreTask> createOpen({
    required String householdId,
    required String templateId,
    DateTime? dueAt,
  }) async {
    return choreTaskFromApi(
      await call(
        () => _tasks.createOpenTask(
          householdId,
          api.CreateOpenTaskRequest(templateId: templateId, dueAt: dueAt),
        ),
      ),
    );
  }

  @override
  Future<ChoreTask> complete(String householdId, String taskId) async =>
      choreTaskFromApi(
        await call(() => _tasks.completeTask(householdId, taskId)),
      );

  @override
  Future<ChoreTask> dismiss(String householdId, String taskId) async =>
      choreTaskFromApi(
        await call(() => _tasks.dismissTask(householdId, taskId)),
      );

  @override
  Future<ChoreTask> reassign(String householdId, String taskId) async =>
      choreTaskFromApi(
        await call(() => _tasks.reassignTask(householdId, taskId)),
      );

  @override
  Future<ChoreTask> revert(
    String householdId,
    String taskId, {
    required String reason,
  }) async {
    return choreTaskFromApi(
      await call(
        () => _tasks.revertTask(
          householdId,
          taskId,
          api.RevertRequest(reason: reason),
        ),
      ),
    );
  }

  @override
  Future<TaskRecurrence?> getRecurrence(
    String householdId,
    String templateId,
  ) async {
    try {
      return taskRecurrenceFromApi(
        await call(() => _recurrence.getRecurrence(householdId, templateId)),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
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
    return taskRecurrenceFromApi(
      await call(
        () => _recurrence.upsertRecurrence(
          householdId,
          templateId,
          api.UpsertRecurrenceRequest(
            rrule: rrule,
            assignmentMode: api.AssignmentMode.values.byName(
              assignmentMode.name,
            ),
            fixedAssigneeId: fixedAssigneeId,
            startsAt: startsAt ?? DateTime.now().toUtc(),
          ),
        ),
      ),
    );
  }

  @override
  Future<int> runDueRecurrences(String householdId) async {
    return 0;
  }
}

class FakeTasksRepository implements TasksRepository {
  FakeTasksRepository({
    this.currentUserId = 'user-1',
    this.ledger,
    this.now = DateTime.now,
  });

  final String currentUserId;

  /// The clock of due dates and completion times. Golden tests pin it so a screen looks the same every day.
  final DateTime Function() now;

  /// Stands in for the real backend, where tasks-service writes the ledger itself.
  final FakeScoringRepository? ledger;
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
  Future<TaskTemplate> updateTemplate({
    required String householdId,
    required String templateId,
    required String title,
    required String emoji,
    required String description,
    required int points,
    required int latePoints,
  }) async {
    final templates = _templates[householdId] ?? [];
    final index = templates.indexWhere((t) => t.id == templateId);
    if (index < 0) {
      throw ApiException('Template not found', statusCode: 404);
    }
    final updated = TaskTemplate(
      id: templateId,
      householdId: householdId,
      title: title,
      emoji: emoji.isEmpty ? null : emoji,
      description: description,
      points: points,
      latePoints: latePoints,
      defaultDueOffsetMinutes: templates[index].defaultDueOffsetMinutes,
    );
    templates[index] = updated;
    return updated;
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
      completedAt: now().toUtc(),
      pointsAwarded: template.points,
    );
    _tasks.putIfAbsent(householdId, () => []).add(task);
    await _award(task);
    return task;
  }

  @override
  Future<ChoreTask> createOpen({
    required String householdId,
    required String templateId,
    DateTime? dueAt,
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
      dueAt: dueAt ?? now().toUtc().add(const Duration(days: 1)),
    );
    _tasks.putIfAbsent(householdId, () => []).add(task);
    return task;
  }

  @override
  Future<ChoreTask> complete(String householdId, String taskId) async {
    final done = _replace(
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
        completedAt: now().toUtc(),
        pointsAwarded: t.points,
      ),
    );
    await _award(done);
    return done;
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
    var credited = 0;
    final reverted = _replace(householdId, taskId, (t) {
      if (t.status != TaskStatus.done) {
        throw ApiException('only done', statusCode: 409);
      }
      credited = t.pointsAwarded ?? t.points;
      final resulting = t.origin == TaskOrigin.manual
          ? TaskStatus.reverted
          : (t.dueAt != null && t.dueAt!.isAfter(now().toUtc())
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
        reversionReason: reason.trim(),
      );
    });
    await ledger?.reverse(
      householdId: householdId,
      taskId: taskId,
      assigneeUserId: reverted.assigneeId,
      points: credited,
      reason: reason,
      resultingStatus: reverted.status.name,
    );
    return reverted;
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
      startsAt: startsAt ?? now().toUtc(),
      nextRunAt: now().toUtc().subtract(const Duration(minutes: 1)),
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
              !r.nextRunAt!.isAfter(now().toUtc()),
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
        dueAt: now().toUtc().add(const Duration(days: 1)),
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
        lastGeneratedAt: now().toUtc(),
        nextRunAt: now().toUtc().add(const Duration(days: 1)),
      );
      spawned++;
    }
    return spawned;
  }

  Future<void> _award(ChoreTask done) async {
    final points = done.pointsAwarded ?? done.points;
    final completedAt = done.completedAt;
    final dueAt = done.dueAt;
    if (points > 0) {
      await ledger?.award(
        householdId: done.householdId,
        userId: done.assigneeId,
        taskId: done.id,
        points: points,
        late:
            dueAt != null && completedAt != null && completedAt.isAfter(dueAt),
      );
    }
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
