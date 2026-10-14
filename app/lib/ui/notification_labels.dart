import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';

/// The name of a notification type in the user's language, for the settings screen.
String notificationTypeLabel(AppLocalizations l10n, NotificationType type) =>
    switch (type) {
      NotificationType.taskAssigned => l10n.typeTaskAssigned,
      NotificationType.taskReassigned => l10n.typeTaskReassigned,
      NotificationType.dueReminder => l10n.typeDueReminder,
      NotificationType.overdue => l10n.typeOverdue,
      NotificationType.dismissed => l10n.typeDismissed,
      NotificationType.superseded => l10n.typeSuperseded,
      NotificationType.reverted => l10n.typeReverted,
      NotificationType.markedAway => l10n.typeMarkedAway,
      NotificationType.invitation => l10n.typeInvitation,
    };

String notificationChannelLabel(
  AppLocalizations l10n,
  NotificationChannel channel,
) => switch (channel) {
  NotificationChannel.push => l10n.channelPush,
  NotificationChannel.inApp => l10n.channelInApp,
};
