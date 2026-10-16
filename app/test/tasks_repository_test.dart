import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fake tasks repository updates a template and keeps the others',
    () async {
      final repo = FakeTasksRepository();
      final bins = await repo.createTemplate(
        householdId: 'hh-1',
        title: 'Bins',
        emoji: '🗑️',
        points: 5,
        latePoints: 2,
      );
      await repo.createTemplate(
        householdId: 'hh-1',
        title: 'Dishes',
        points: 3,
        latePoints: 1,
      );

      final updated = await repo.updateTemplate(
        householdId: 'hh-1',
        templateId: bins.id,
        title: 'Bins out',
        emoji: '',
        description: 'Monday',
        points: 7,
        latePoints: 4,
      );

      expect(updated.title, 'Bins out');
      expect(updated.emoji, isNull);
      final all = await repo.listTemplates('hh-1');
      expect(all.map((t) => t.title), ['Bins out', 'Dishes']);
      expect(all.first.points, 7);
    },
  );

  test('fake tasks repository refuses to update an unknown template', () async {
    await expectLater(
      FakeTasksRepository().updateTemplate(
        householdId: 'hh-1',
        templateId: 'nope',
        title: 'x',
        emoji: '',
        description: '',
        points: 1,
        latePoints: 1,
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('fake tasks repository quick-logs and completes', () async {
    final repo = FakeTasksRepository();
    final template = await repo.createTemplate(
      householdId: 'hh-1',
      title: 'Bins',
      points: 5,
      latePoints: 2,
    );
    final logged = await repo.quickLog(
      householdId: 'hh-1',
      templateId: template.id,
    );
    expect(logged.status, TaskStatus.done);
    expect(logged.pointsAwarded, 5);

    final open = await repo.createOpen(
      householdId: 'hh-1',
      templateId: template.id,
    );
    final done = await repo.complete('hh-1', open.id);
    expect(done.status, TaskStatus.done);
  });

  test('fake recurrence upsert and spawn supersedes open', () async {
    final repo = FakeTasksRepository();
    final template = await repo.createTemplate(
      householdId: 'hh-1',
      title: 'Dust',
      points: 3,
      latePoints: 1,
    );
    await repo.upsertRecurrence(
      householdId: 'hh-1',
      templateId: template.id,
      rrule: 'FREQ=DAILY',
      assignmentMode: AssignmentMode.roundRobin,
    );
    expect(await repo.runDueRecurrences('hh-1'), 1);
    final firstOpen = await repo.listTasks('hh-1', status: TaskStatus.open);
    expect(firstOpen, hasLength(1));
    // Make due again and spawn — previous open recurrence is superseded.
    await repo.upsertRecurrence(
      householdId: 'hh-1',
      templateId: template.id,
      rrule: 'FREQ=DAILY',
      assignmentMode: AssignmentMode.roundRobin,
    );
    expect(await repo.runDueRecurrences('hh-1'), 1);
    final open = await repo.listTasks('hh-1', status: TaskStatus.open);
    expect(open, hasLength(1));
    expect(open.single.origin, TaskOrigin.recurrence);
    expect(open.single.id, isNot(firstOpen.single.id));
    final dismissed = await repo.listTasks(
      'hh-1',
      status: TaskStatus.dismissed,
    );
    expect(dismissed, hasLength(1));
  });
}
