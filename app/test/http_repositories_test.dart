import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome_api/api.dart' as api;
import 'package:flutter_test/flutter_test.dart';

import 'support/contract_server.dart';

const _household = 'h-1';
const _sampleId = '2f5b7c1e-0d3a-4c1b-9a53-6f0e5b8d1a42';

void main() {
  late ContractServer server;

  setUp(() => server = ContractServer.load());

  HttpHouseholdsRepository households() => HttpHouseholdsRepository(
    baseUrl: 'http://households.test/',
    accessToken: () => 'test-token',
    client: server.client,
  );

  HttpTasksRepository tasks() => HttpTasksRepository(
    baseUrl: 'http://tasks.test',
    accessToken: () => 'test-token',
    client: server.client,
  );

  HttpScoringRepository scoring() => HttpScoringRepository(
    baseUrl: 'http://scoring.test',
    accessToken: () => 'test-token',
    client: server.client,
  );

  group('households', () {
    test(
      'profile sync sends the contract request and maps the answer',
      () async {
        final me = await households().syncMe(
          email: 'a@example.com',
          givenName: 'A',
          language: 'fr',
          timezone: 'Europe/Brussels',
        );

        expect(server.requests, ['PUT /v1/me']);
        expect(
          server.lastBody['syncMyProfile'],
          containsPair('language', 'fr'),
        );
        expect(me.id, _sampleId);
        expect(me.email, 'text');
      },
    );

    test('reads profile, households and members', () async {
      final repo = households();

      expect((await repo.getMe()).id, _sampleId);
      expect((await repo.listHouseholds()).single.reminderTime, '08:00:00');
      expect((await repo.getHousehold(_household)).name, 'text');
      final member = (await repo.listMembers(_household)).single;
      expect(member.role, MembershipRole.admin);
      expect(member.joinedAt, DateTime.utc(2026, 1, 15, 10));
      expect(server.requests, [
        'GET /v1/me',
        'GET /v1/households',
        'GET /v1/households/$_household',
        'GET /v1/households/$_household/members',
      ]);
    });

    test('creates a household and an invitation, accepts it', () async {
      final repo = households();

      await repo.createHousehold(name: 'Home', timezone: 'UTC');
      final invitation = await repo.createInvitation(
        householdId: _household,
        email: 'b@example.com',
        role: MembershipRole.admin,
      );
      await repo.acceptInvitation(invitation.token);

      expect(
        server.lastBody['createInvitation'],
        containsPair('role', 'admin'),
      );
      expect(server.requests, [
        'POST /v1/households',
        'POST /v1/households/$_household/invitations',
        'POST /v1/invitations/text/accept',
      ]);
    });

    test('sets and clears away, leaves', () async {
      final repo = households();

      await repo.setAway(_household, _sampleId);
      await repo.clearAway(_household, _sampleId);
      await repo.leave(_household);

      expect(server.requests, [
        'POST /v1/households/$_household/members/$_sampleId/away',
        'DELETE /v1/households/$_household/members/$_sampleId/away',
        'POST /v1/households/$_household/members/me/leave',
      ]);
    });

    test('an error answer becomes an ApiException with its status', () async {
      server.respondWith('createHousehold', 403, {
        'code': 'forbidden',
        'message': 'no',
      });

      await expectLater(
        households().createHousehold(name: 'Home', timezone: 'UTC'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    });

    test('a missing token is refused by the server', () async {
      final repo = HttpHouseholdsRepository(
        baseUrl: 'http://households.test',
        accessToken: () => '',
        client: server.client,
      );

      await expectLater(
        repo.getMe(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });

    test('a response without a field the app needs is reported', () async {
      server.respondWith('getMyProfile', 200, {'email': 'a@example.com'});

      await expectLater(
        households().getMe(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('id'),
          ),
        ),
      );
    });
  });

  group('tasks', () {
    test('templates', () async {
      final repo = tasks();

      expect((await repo.listTemplates(_household)).single.points, 1);
      final created = await repo.createTemplate(
        householdId: _household,
        title: 'Bins',
        points: 5,
        latePoints: 2,
      );

      expect(created.title, 'text');
      expect(server.lastBody['createTemplate'], containsPair('points', 5));
    });

    test('lists tasks with the declared query parameters', () async {
      final list = await tasks().listTasks(
        _household,
        status: TaskStatus.done,
        mine: true,
      );

      expect(list.single.status, TaskStatus.open);
      expect(list.single.reversionReason, 'text');
      expect(server.lastQuery['listTasks'], 'mine=true&status=done');
      expect(server.requests, ['GET /v1/households/$_household/tasks']);
    });

    test('an open task can be created with a due date', () async {
      final due = DateTime.utc(2026, 10, 1, 9);

      await tasks().createOpen(
        householdId: _household,
        templateId: _sampleId,
        dueAt: due,
      );

      expect(
        server.lastBody['createOpenTask'],
        containsPair('dueAt', due.toIso8601String()),
      );
    });

    test('creates, completes, dismisses, reassigns and reverts', () async {
      final repo = tasks();

      await repo.quickLog(householdId: _household, templateId: _sampleId);
      await repo.createOpen(householdId: _household, templateId: _sampleId);
      await repo.complete(_household, _sampleId);
      await repo.dismiss(_household, _sampleId);
      await repo.reassign(_household, _sampleId);
      await repo.revert(_household, _sampleId, reason: 'mistake');

      expect(server.lastBody['revertTask'], containsPair('reason', 'mistake'));
      expect(server.requests, [
        'POST /v1/households/$_household/tasks/manual',
        'POST /v1/households/$_household/tasks',
        'POST /v1/households/$_household/tasks/$_sampleId/complete',
        'POST /v1/households/$_household/tasks/$_sampleId/dismiss',
        'POST /v1/households/$_household/tasks/$_sampleId/reassign',
        'POST /v1/households/$_household/tasks/$_sampleId/revert',
      ]);
    });

    test('recurrence: read, absent and upsert', () async {
      final repo = tasks();

      expect((await repo.getRecurrence(_household, _sampleId))?.rrule, 'text');
      server.respondWith('getRecurrence', 404, {
        'code': 'not_found',
        'message': 'none',
      });
      expect(await repo.getRecurrence(_household, _sampleId), isNull);

      final saved = await repo.upsertRecurrence(
        householdId: _household,
        templateId: _sampleId,
        rrule: 'FREQ=DAILY',
        assignmentMode: AssignmentMode.roundRobin,
      );

      expect(saved.assignmentMode, AssignmentMode.fixed);
      expect(
        server.lastBody['upsertRecurrence'],
        containsPair('assignmentMode', 'round_robin'),
      );
    });
  });

  group('lists', () {
    HttpListsRepository lists() => HttpListsRepository(
      baseUrl: 'http://lists.test',
      accessToken: () => 'test-token',
      client: server.client,
    );

    test('lists, creates, renames and archives', () async {
      final repo = lists();

      expect((await repo.listLists(_household)).single.title, 'text');
      await repo.createList(_household, 'Groceries');
      await repo.renameList(_household, _sampleId, 'Food');
      final archived = await repo.archiveList(_household, _sampleId);

      expect(archived.isArchived, isTrue);
      expect(server.lastBody['createList'], containsPair('title', 'Groceries'));
      expect(server.lastBody['renameList'], containsPair('title', 'Food'));
      expect(server.requests, [
        'GET /v1/households/$_household/lists',
        'POST /v1/households/$_household/lists',
        'PATCH /v1/households/$_household/lists/$_sampleId',
        'POST /v1/households/$_household/lists/$_sampleId/archive',
      ]);
    });

    test('adds, checks, unchecks, deletes and resets items', () async {
      final repo = lists();

      expect((await repo.listItems(_household, _sampleId)).single.position, 1);
      await repo.addItem(_household, _sampleId, 'Milk');
      final checked = await repo.checkItem(_household, _sampleId, _sampleId);
      await repo.uncheckItem(_household, _sampleId, _sampleId);
      await repo.deleteItem(_household, _sampleId, _sampleId);
      final reset = await repo.resetList(_household, _sampleId);

      expect(checked.isChecked, isTrue);
      expect(reset, hasLength(1));
      expect(server.lastBody['addItem'], containsPair('title', 'Milk'));
      expect(server.requests, [
        'GET /v1/households/$_household/lists/$_sampleId/items',
        'POST /v1/households/$_household/lists/$_sampleId/items',
        'POST /v1/households/$_household/lists/$_sampleId/items/$_sampleId/check',
        'POST /v1/households/$_household/lists/$_sampleId/items/$_sampleId/uncheck',
        'DELETE /v1/households/$_household/lists/$_sampleId/items/$_sampleId',
        'POST /v1/households/$_household/lists/$_sampleId/reset',
      ]);
    });

    test('a change to an archived list is reported with its status', () async {
      server.respondWith('addItem', 409, {
        'code': 'conflict',
        'message': 'archived',
      });

      await expectLater(
        lists().addItem(_household, _sampleId, 'Milk'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
    });
  });

  group('notifications', () {
    HttpNotificationsRepository notifications() => HttpNotificationsRepository(
      baseUrl: 'http://notifications.test',
      accessToken: () => 'test-token',
      client: server.client,
    );

    test('lists the inbox with the declared paging parameters', () async {
      final list = await notifications().list(
        before: _sampleId,
        limit: 5,
        unreadOnly: true,
      );

      expect(list.single.type, NotificationType.taskAssigned);
      expect(list.single.title, 'text');
      expect(server.requests, ['GET /v1/notifications']);
      expect(
        server.lastQuery['listMyNotifications'],
        'before=$_sampleId&limit=5&unreadOnly=true',
      );
    });

    test('marks one read and all read', () async {
      final repo = notifications();

      final read = await repo.markRead(_sampleId);
      final changed = await repo.markAllRead();

      expect(read.isRead, isTrue);
      expect(changed, 1);
      expect(server.requests, [
        'POST /v1/notifications/$_sampleId/read',
        'POST /v1/notifications/read-all',
      ]);
    });

    test(
      'reads and changes a preference with the API values in the path',
      () async {
        final repo = notifications();

        final all = await repo.preferences();
        final saved = await repo.setPreference(
          NotificationType.markedAway,
          NotificationChannel.inApp,
          enabled: false,
        );

        expect(all.single.enabled, isTrue);
        expect(saved.channel, NotificationChannel.push);
        expect(server.lastBody['updateMyNotificationPreference'], {
          'enabled': false,
        });
        expect(server.requests, [
          'GET /v1/notification-preferences',
          'PUT /v1/notification-preferences/marked_away/in_app',
        ]);
      },
    );

    test('an error answer becomes an ApiException', () async {
      server.respondWith('markMyNotificationRead', 404, {
        'code': 'not_found',
        'message': 'none',
      });

      await expectLater(
        notifications().markRead(_sampleId),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('scoring', () {
    test('scoreboard and winners', () async {
      final board = await scoring().getScoreboard(
        _household,
        period: ScorePeriod.all,
      );
      final winners = await scoring().listWinners(_household);

      expect(board.entries.single.rank, 1);
      expect(board.podium, hasLength(1));
      expect(winners.single.yearMonth, 'text');
      expect(
        winners.single.celebrated,
        isTrue,
        reason: 'the sample answer has every field',
      );
      expect(server.requests, [
        'GET /v1/households/$_household/scoreboard',
        'GET /v1/households/$_household/scoreboard/winners',
      ]);
    });
  });

  group('month recap', () {
    test('tells the server the recap was seen', () async {
      await scoring().markRecapCelebrated(_household, '2026-09');

      expect(server.requests, [
        'POST /v1/households/$_household/scoreboard/recaps/2026-09/celebrate',
      ]);
    });

    test('an error answer becomes an ApiException', () async {
      server.respondWith('markRecapCelebrated', 404, {
        'code': 'not_found',
        'message': 'none',
      });

      await expectLater(
        scoring().markRecapCelebrated(_household, '2026-09'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('enums', () {
    // The app maps generated enums to its own by name: every value of the contract must exist there.
    test('every contract value maps to an app value', () {
      void check<G extends Enum>(
        String schema,
        List<G> generated,
        List<Enum> app,
      ) {
        expect(
          generated.map((v) => v.toString()).toList(),
          server.enumValues(schema),
          reason: '$schema: generated client differs from the contract',
        );
        final names = app.map((v) => v.name).toSet();
        for (final value in generated) {
          expect(names, contains(value.name), reason: '$schema.${value.name}');
        }
      }

      check('MembershipRole', api.MembershipRole.values, MembershipRole.values);
      check('TaskStatus', api.TaskStatus.values, TaskStatus.values);
      check('TaskOrigin', api.TaskOrigin.values, TaskOrigin.values);
      check('AssignmentMode', api.AssignmentMode.values, AssignmentMode.values);
      check('ScorePeriod', api.ScorePeriod.values, ScorePeriod.values);
      check(
        'NotificationType',
        api.NotificationType.values,
        NotificationType.values,
      );
      check('Channel', api.Channel.values, NotificationChannel.values);
    });
  });
}
