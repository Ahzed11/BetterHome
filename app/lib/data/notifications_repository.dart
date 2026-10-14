import 'package:betterhome/data/api_mappers.dart';
import 'package:betterhome/data/api_support.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome_api/api.dart' as api;
import 'package:http/http.dart' as http;

/// The kinds of notification of spec section 5. The names match the generated client's enum.
enum NotificationType {
  taskAssigned,
  taskReassigned,
  dueReminder,
  overdue,
  dismissed,
  superseded,
  reverted,
  markedAway,
  invitation,
}

/// Where a notification is delivered.
enum NotificationChannel { push, inApp }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
}

class NotificationPreference {
  const NotificationPreference({
    required this.type,
    required this.channel,
    required this.enabled,
  });

  final NotificationType type;
  final NotificationChannel channel;
  final bool enabled;
}

/// The caller's inbox and notification settings. Notifications are per user, not per household.
abstract class NotificationsRepository {
  /// Newest first. Pass the id of the last item of the previous page as [before] for the next one.
  Future<List<AppNotification>> list({
    String? before,
    int limit = 20,
    bool unreadOnly = false,
  });

  Future<AppNotification> markRead(String id);

  /// Marks every notification read and returns how many changed.
  Future<int> markAllRead();

  /// One entry per type and channel; all are on unless the user switched them off.
  Future<List<NotificationPreference>> preferences();

  Future<NotificationPreference> setPreference(
    NotificationType type,
    NotificationChannel channel, {
    required bool enabled,
  });
}

class HttpNotificationsRepository implements NotificationsRepository {
  HttpNotificationsRepository({
    required String baseUrl,
    required String Function() accessToken,
    http.Client? client,
  }) : _client = buildApiClient(
         baseUrl: baseUrl,
         accessToken: accessToken,
         client: client,
       );

  final api.ApiClient _client;

  api.NotificationsApi get _notifications => api.NotificationsApi(_client);
  api.PreferencesApi get _preferences => api.PreferencesApi(_client);

  @override
  Future<List<AppNotification>> list({
    String? before,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final list = await call(
      () => _notifications.listMyNotifications(
        before: before,
        limit: limit,
        unreadOnly: unreadOnly,
      ),
    );
    return list.map(appNotificationFromApi).toList();
  }

  @override
  Future<AppNotification> markRead(String id) async => appNotificationFromApi(
    await call(() => _notifications.markMyNotificationRead(id)),
  );

  @override
  Future<int> markAllRead() async {
    final result = await call(_notifications.markAllMyNotificationsRead);
    return need(result.updated, 'updated');
  }

  @override
  Future<List<NotificationPreference>> preferences() async {
    final list = await call(_preferences.listMyNotificationPreferences);
    return list.map(notificationPreferenceFromApi).toList();
  }

  @override
  Future<NotificationPreference> setPreference(
    NotificationType type,
    NotificationChannel channel, {
    required bool enabled,
  }) async {
    return notificationPreferenceFromApi(
      await call(
        () => _preferences.updateMyNotificationPreference(
          api.Channel.values.byName(channel.name).toString(),
          api.NotificationType.values.byName(type.name).toString(),
          api.UpdatePreferenceRequest(enabled: enabled),
        ),
      ),
    );
  }
}

/// In-memory repository for widget tests and offline demo mode. Starts with an empty inbox; tests
/// put notifications in with [add].
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository();

  final List<AppNotification> _inbox = [];
  final Map<(NotificationType, NotificationChannel), bool> _switched = {};

  /// Puts a notification at the top of the inbox.
  void add(AppNotification notification) => _inbox.insert(0, notification);

  @override
  Future<List<AppNotification>> list({
    String? before,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    var items = unreadOnly ? _inbox.where((n) => !n.isRead).toList() : _inbox;
    if (before != null) {
      final index = items.indexWhere((n) => n.id == before);
      items = index < 0 ? const [] : items.sublist(index + 1);
    }
    return List.unmodifiable(items.take(limit));
  }

  @override
  Future<AppNotification> markRead(String id) async {
    final index = _inbox.indexWhere((n) => n.id == id);
    if (index < 0) {
      throw ApiException('not found', statusCode: 404);
    }
    final current = _inbox[index];
    if (current.isRead) {
      return current;
    }
    final read = AppNotification(
      id: current.id,
      type: current.type,
      title: current.title,
      body: current.body,
      createdAt: current.createdAt,
      readAt: DateTime.now().toUtc(),
    );
    _inbox[index] = read;
    return read;
  }

  @override
  Future<int> markAllRead() async {
    var changed = 0;
    for (final n in List<AppNotification>.of(_inbox)) {
      if (!n.isRead) {
        await markRead(n.id);
        changed++;
      }
    }
    return changed;
  }

  @override
  Future<List<NotificationPreference>> preferences() async => [
    for (final type in NotificationType.values)
      for (final channel in NotificationChannel.values)
        NotificationPreference(
          type: type,
          channel: channel,
          enabled: _switched[(type, channel)] ?? true,
        ),
  ];

  @override
  Future<NotificationPreference> setPreference(
    NotificationType type,
    NotificationChannel channel, {
    required bool enabled,
  }) async {
    _switched[(type, channel)] = enabled;
    return NotificationPreference(
      type: type,
      channel: channel,
      enabled: enabled,
    );
  }
}
