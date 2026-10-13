import 'package:betterhome/data/tasks_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
