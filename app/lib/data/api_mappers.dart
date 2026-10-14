import 'package:betterhome/data/api_support.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome_api/api.dart' as api;

// Generated response models have only nullable fields (the contract marks none as required),
// so each mapper states which fields the app needs through `need`.

UserProfile userProfileFromApi(api.UserResponse r) => UserProfile(
  id: need(r.id, 'id'),
  authSubject: need(r.authSubject, 'authSubject'),
  email: need(r.email, 'email'),
  givenName: r.givenName ?? '',
  familyName: r.familyName ?? '',
  language: r.language ?? 'en',
  timezone: r.timezone ?? 'UTC',
);

Household householdFromApi(api.HouseholdResponse r) => Household(
  id: need(r.id, 'id'),
  name: need(r.name, 'name'),
  timezone: need(r.timezone, 'timezone'),
  reminderDaysBefore: r.reminderDaysBefore ?? 0,
  reminderTime: r.reminderTime ?? '08:00:00',
  createdBy: need(r.createdBy, 'createdBy'),
);

Membership membershipFromApi(api.MembershipResponse r) => Membership(
  id: need(r.id, 'id'),
  userId: need(r.userId, 'userId'),
  householdId: need(r.householdId, 'householdId'),
  role: MembershipRole.values.byName(need(r.role, 'role').name),
  joinedAt: need(r.joinedAt, 'joinedAt'),
  awayFrom: r.awayFrom,
  awayUntil: r.awayUntil,
  awaySetBy: r.awaySetBy,
);

Invitation invitationFromApi(api.InvitationResponse r) => Invitation(
  id: need(r.id, 'id'),
  householdId: need(r.householdId, 'householdId'),
  email: need(r.email, 'email'),
  role: MembershipRole.values.byName(need(r.role, 'role').name),
  token: need(r.token, 'token'),
  expiresAt: need(r.expiresAt, 'expiresAt'),
  acceptedAt: r.acceptedAt,
);

TaskTemplate taskTemplateFromApi(api.TemplateResponse r) => TaskTemplate(
  id: need(r.id, 'id'),
  householdId: need(r.householdId, 'householdId'),
  title: need(r.title, 'title'),
  emoji: r.emoji,
  description: r.description ?? '',
  points: need(r.points, 'points'),
  latePoints: need(r.latePoints, 'latePoints'),
  defaultDueOffsetMinutes: r.defaultDueOffsetMinutes ?? 1440,
);

ChoreTask choreTaskFromApi(api.TaskResponse r) => ChoreTask(
  id: need(r.id, 'id'),
  householdId: need(r.householdId, 'householdId'),
  templateId: need(r.templateId, 'templateId'),
  origin: TaskOrigin.values.byName(need(r.origin, 'origin').name),
  title: need(r.title, 'title'),
  emoji: r.emoji,
  points: need(r.points, 'points'),
  latePoints: need(r.latePoints, 'latePoints'),
  status: TaskStatus.values.byName(need(r.status, 'status').name),
  assigneeId: need(r.assigneeId, 'assigneeId'),
  dueAt: r.dueAt,
  completedAt: r.completedAt,
  pointsAwarded: r.pointsAwarded,
);

TaskRecurrence taskRecurrenceFromApi(api.RecurrenceResponse r) =>
    TaskRecurrence(
      id: need(r.id, 'id'),
      householdId: need(r.householdId, 'householdId'),
      templateId: need(r.templateId, 'templateId'),
      rrule: need(r.rrule, 'rrule'),
      assignmentMode: AssignmentMode.values.byName(
        need(r.assignmentMode, 'assignmentMode').name,
      ),
      fixedAssigneeId: r.fixedAssigneeId,
      timezone: need(r.timezone, 'timezone'),
      startsAt: need(r.startsAt, 'startsAt'),
      endsAt: r.endsAt,
      lastGeneratedAt: r.lastGeneratedAt,
      nextRunAt: r.nextRunAt,
    );

ScoreEntry scoreEntryFromApi(api.ScoreEntryResponse r) => ScoreEntry(
  userId: need(r.userId, 'userId'),
  points: need(r.points, 'points'),
  effortShare: need(r.effortShare, 'effortShare'),
  rank: need(r.rank, 'rank'),
);

Scoreboard scoreboardFromApi(api.ScoreboardResponse r) => Scoreboard(
  period: ScorePeriod.values.byName(need(r.period, 'period').name),
  yearMonth: r.yearMonth,
  totalPoints: need(r.totalPoints, 'totalPoints'),
  entries: r.entries.map(scoreEntryFromApi).toList(),
  podium: r.podium.map(scoreEntryFromApi).toList(),
);

MonthlyWinner monthlyWinnerFromApi(api.WinnerResponse r) => MonthlyWinner(
  yearMonth: need(r.yearMonth, 'yearMonth'),
  winnerUserId: r.winnerUserId,
  winnerPoints: need(r.winnerPoints, 'winnerPoints'),
  totalPoints: need(r.totalPoints, 'totalPoints'),
);

Checklist checklistFromApi(api.ListResponse r) => Checklist(
  id: need(r.id, 'id'),
  householdId: need(r.householdId, 'householdId'),
  title: need(r.title, 'title'),
  archivedAt: r.archivedAt,
);

ChecklistItem checklistItemFromApi(api.ItemResponse r) => ChecklistItem(
  id: need(r.id, 'id'),
  listId: need(r.listId, 'listId'),
  title: need(r.title, 'title'),
  position: need(r.position, 'position'),
  completedAt: r.completedAt,
);
