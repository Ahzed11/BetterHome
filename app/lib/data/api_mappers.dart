import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome_api/api.dart' as api;

UserProfile userProfileFromApi(api.UserResponse r) => UserProfile(
  id: r.id,
  authSubject: r.authSubject,
  email: r.email,
  givenName: r.givenName,
  familyName: r.familyName,
  language: r.language,
  timezone: r.timezone,
);

Household householdFromApi(api.HouseholdResponse r) => Household(
  id: r.id,
  name: r.name,
  timezone: r.timezone,
  reminderDaysBefore: r.reminderDaysBefore,
  reminderTime: r.reminderTime,
  createdBy: r.createdBy,
);

Membership membershipFromApi(api.MembershipResponse r) => Membership(
  id: r.id,
  userId: r.userId,
  householdId: r.householdId,
  role: MembershipRole.values.byName(r.role.name),
  joinedAt: r.joinedAt,
  awayFrom: r.awayFrom,
  awayUntil: r.awayUntil,
  awaySetBy: r.awaySetBy,
  givenName: r.givenName,
  familyName: r.familyName,
);

Invitation invitationFromApi(api.InvitationResponse r) => Invitation(
  id: r.id,
  householdId: r.householdId,
  email: r.email,
  role: MembershipRole.values.byName(r.role.name),
  token: r.token,
  expiresAt: r.expiresAt,
  acceptedAt: r.acceptedAt,
);

TaskTemplate taskTemplateFromApi(api.TemplateResponse r) => TaskTemplate(
  id: r.id,
  householdId: r.householdId,
  title: r.title,
  emoji: r.emoji,
  description: r.description,
  points: r.points,
  latePoints: r.latePoints,
  defaultDueOffsetMinutes: r.defaultDueOffsetMinutes,
);

ChoreTask choreTaskFromApi(api.TaskResponse r) => ChoreTask(
  id: r.id,
  householdId: r.householdId,
  templateId: r.templateId,
  origin: TaskOrigin.values.byName(r.origin.name),
  title: r.title,
  emoji: r.emoji,
  points: r.points,
  latePoints: r.latePoints,
  status: TaskStatus.values.byName(r.status.name),
  assigneeId: r.assigneeId,
  dueAt: r.dueAt,
  completedAt: r.completedAt,
  pointsAwarded: r.pointsAwarded,
  reversionReason: r.reversionReason,
);

TaskRecurrence taskRecurrenceFromApi(api.RecurrenceResponse r) =>
    TaskRecurrence(
      id: r.id,
      householdId: r.householdId,
      templateId: r.templateId,
      rrule: r.rrule,
      assignmentMode: AssignmentMode.values.byName(r.assignmentMode.name),
      fixedAssigneeId: r.fixedAssigneeId,
      timezone: r.timezone,
      startsAt: r.startsAt,
      endsAt: r.endsAt,
      lastGeneratedAt: r.lastGeneratedAt,
      nextRunAt: r.nextRunAt,
    );

ScoreEntry scoreEntryFromApi(api.ScoreEntryResponse r) => ScoreEntry(
  userId: r.userId,
  points: r.points,
  effortShare: r.effortShare,
  rank: r.rank,
);

Scoreboard scoreboardFromApi(api.ScoreboardResponse r) => Scoreboard(
  period: ScorePeriod.values.byName(r.period.name),
  yearMonth: r.yearMonth,
  totalPoints: r.totalPoints,
  entries: r.entries.map(scoreEntryFromApi).toList(),
  podium: r.podium.map(scoreEntryFromApi).toList(),
);

MonthlyWinner monthlyWinnerFromApi(api.WinnerResponse r) => MonthlyWinner(
  yearMonth: r.yearMonth,
  winnerUserId: r.winnerUserId,
  winnerPoints: r.winnerPoints,
  totalPoints: r.totalPoints,
  celebrated: r.celebrated,
);

Checklist checklistFromApi(api.ListResponse r) => Checklist(
  id: r.id,
  householdId: r.householdId,
  title: r.title,
  archivedAt: r.archivedAt,
);

ChecklistItem checklistItemFromApi(api.ItemResponse r) => ChecklistItem(
  id: r.id,
  listId: r.listId,
  title: r.title,
  position: r.position,
  completedAt: r.completedAt,
);

AppNotification appNotificationFromApi(api.NotificationResponse r) =>
    AppNotification(
      id: r.id,
      type: NotificationType.values.byName(r.type.name),
      title: r.title,
      body: r.body,
      createdAt: r.createdAt,
      readAt: r.readAt,
    );

NotificationPreference notificationPreferenceFromApi(
  api.PreferenceResponse r,
) => NotificationPreference(
  type: NotificationType.values.byName(r.type.name),
  channel: NotificationChannel.values.byName(r.channel.name),
  enabled: r.enabled,
);
