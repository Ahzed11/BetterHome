import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _notification(String id, {DateTime? readAt}) => AppNotification(
  id: id,
  type: NotificationType.taskAssigned,
  title: 'New chore $id',
  body: 'Body $id',
  createdAt: DateTime.utc(2026, 10, 14, 10),
  readAt: readAt,
);

void main() {
  test(
    'the inbox is newest first and pages with the last id as cursor',
    () async {
      final repo = FakeNotificationsRepository();
      for (var i = 1; i <= 5; i++) {
        repo.add(_notification('n$i'));
      }

      final first = await repo.list(limit: 2);
      final second = await repo.list(before: first.last.id, limit: 2);
      final rest = await repo.list(before: second.last.id, limit: 2);

      expect(first.map((n) => n.id), ['n5', 'n4']);
      expect(second.map((n) => n.id), ['n3', 'n2']);
      expect(rest.map((n) => n.id), ['n1']);
    },
  );

  test('an unknown cursor gives an empty page', () async {
    final repo = FakeNotificationsRepository()..add(_notification('n1'));

    expect(await repo.list(before: 'nope'), isEmpty);
  });

  test('unreadOnly leaves out what was read', () async {
    final repo = FakeNotificationsRepository()
      ..add(_notification('read', readAt: DateTime.utc(2026, 10, 14)))
      ..add(_notification('unread'));

    final unread = await repo.list(unreadOnly: true);

    expect(unread.map((n) => n.id), ['unread']);
  });

  test(
    'marking read keeps the first read time and unknown ids are 404',
    () async {
      final repo = FakeNotificationsRepository()..add(_notification('n1'));

      final first = await repo.markRead('n1');
      final again = await repo.markRead('n1');

      expect(first.isRead, isTrue);
      expect(again.readAt, first.readAt);
      await expectLater(
        repo.markRead('missing'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    },
  );

  test('mark all read counts only what changed', () async {
    final repo = FakeNotificationsRepository()
      ..add(_notification('a'))
      ..add(_notification('b', readAt: DateTime.utc(2026, 10, 14)));

    expect(await repo.markAllRead(), 1);
    expect(await repo.markAllRead(), 0);
    expect(await repo.list(unreadOnly: true), isEmpty);
  });

  test('every type and channel is on until switched off', () async {
    final repo = FakeNotificationsRepository();

    var all = await repo.preferences();
    expect(
      all.length,
      NotificationType.values.length * NotificationChannel.values.length,
    );
    expect(all.every((p) => p.enabled), isTrue);

    await repo.setPreference(
      NotificationType.overdue,
      NotificationChannel.push,
      enabled: false,
    );
    all = await repo.preferences();

    expect(
      all.where((p) => !p.enabled).map((p) => (p.type, p.channel)).toList(),
      [(NotificationType.overdue, NotificationChannel.push)],
    );
  });
}
