// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BetterHome';

  @override
  String get householdsEmpty => 'No households yet. Create one to get started.';

  @override
  String get createHousehold => 'Create household';

  @override
  String get householdName => 'Household name';

  @override
  String get timezone => 'Timezone';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get members => 'Members';

  @override
  String get invite => 'Invite';

  @override
  String get inviteEmail => 'Email to invite';

  @override
  String get roleMember => 'Member';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get sendInvite => 'Send invitation';

  @override
  String get inviteCreated => 'Invitation created';

  @override
  String copyToken(String token) {
    return 'Token: $token';
  }

  @override
  String get acceptInvite => 'Accept invitation';

  @override
  String get inviteToken => 'Invitation token';

  @override
  String get leaveHousehold => 'Leave household';

  @override
  String get setAway => 'Mark away';

  @override
  String get clearAway => 'Clear away';

  @override
  String get away => 'Away';

  @override
  String get syncProfileTitle => 'Your profile';

  @override
  String get syncProfileSubtitle =>
      'Sync your account with BetterHome before joining a household.';

  @override
  String get email => 'Email';

  @override
  String get givenName => 'First name';

  @override
  String get familyName => 'Last name';

  @override
  String get language => 'Language';

  @override
  String get continueLabel => 'Continue';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get retry => 'Retry';

  @override
  String get useDemoData => 'Continue with demo data';

  @override
  String get loading => 'Loading…';

  @override
  String get choresTitle => 'Chores';

  @override
  String get allChores => 'All chores';

  @override
  String get myChores => 'My chores';

  @override
  String get choresEmpty => 'No chores yet. Quick-log something you just did.';

  @override
  String get quickLog => 'I just did…';

  @override
  String get completeTask => 'Complete';

  @override
  String get dismissTask => 'Dismiss';

  @override
  String get dismissConfirmTitle => 'Dismiss this chore?';

  @override
  String get dismissConfirmBody =>
      'Dismissal is permanent and awards no points.';

  @override
  String get createTemplate => 'New chore template';

  @override
  String get templateTitle => 'Title';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String get periodAll => 'All time';

  @override
  String get podiumTitle => 'Podium';

  @override
  String get effortBarTitle => 'Shared effort';

  @override
  String get hallOfWinners => 'Hall of winners';

  @override
  String get leaderboardEmpty => 'No points yet this period.';

  @override
  String get noWinnersYet => 'No past winners yet.';

  @override
  String pointsLabel(int points) {
    return '$points pts';
  }

  @override
  String get you => 'You';

  @override
  String get revertTask => 'Revert';

  @override
  String get revertConfirmTitle => 'Revert this completion?';

  @override
  String get revertConfirmBody =>
      'Points will be reversed. Please give a reason.';

  @override
  String get revertReason => 'Reason';

  @override
  String get makeRecurring => 'Make recurring';

  @override
  String get recurrenceDaily => 'Daily';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceMonthly => 'Monthly';

  @override
  String get runDueNow => 'Spawn due chores';

  @override
  String get recurrenceSet => 'Recurrence saved';

  @override
  String spawnedCount(int count) {
    return 'Spawned $count chore(s)';
  }

  @override
  String get signInTitle => 'Welcome to BetterHome';

  @override
  String get signInSubtitle =>
      'Sign in to share chores, points and lists with your home.';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get signInFailed => 'Sign-in did not complete. Try again.';

  @override
  String get signOut => 'Sign out';

  @override
  String get createList => 'Create list';

  @override
  String get listName => 'List name';

  @override
  String get renameList => 'Rename';

  @override
  String get archiveList => 'Archive';

  @override
  String get archiveListConfirmTitle => 'Archive this list?';

  @override
  String get archiveListConfirmBody =>
      'Archived lists disappear from this screen and can no longer be changed.';

  @override
  String get itemsEmpty => 'Nothing here yet. Add the first item.';

  @override
  String get deleteItem => 'Delete item';

  @override
  String get resetList => 'Uncheck all';

  @override
  String get resetListConfirmTitle => 'Uncheck every item?';

  @override
  String get resetListConfirmBody =>
      'Use this to start the list over, for example a packing list.';

  @override
  String get listsTitle => 'Lists';

  @override
  String get listsEmpty => 'No lists yet. An admin can create one.';

  @override
  String get newList => 'New list';

  @override
  String get addItem => 'Add an item';

  @override
  String get addItemHint => 'Add an item…';

  @override
  String get addItemButton => 'Add';

  @override
  String get basketTitle => 'In the basket';

  @override
  String get listOptions => 'List options';

  @override
  String checkItem(String title) {
    return 'Check $title';
  }

  @override
  String uncheckItem(String title) {
    return 'Uncheck $title';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'You\'re all caught up.';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get loadMore => 'Load more';

  @override
  String get notificationSettings => 'Notification settings';

  @override
  String get channelPush => 'Push';

  @override
  String get channelInApp => 'In the app';

  @override
  String get notificationsBellUnread => 'Notifications, unread';

  @override
  String get unreadLabel => 'unread';

  @override
  String get typeTaskAssigned => 'New chore';

  @override
  String get typeTaskReassigned => 'Chore reassigned to you';

  @override
  String get typeDueReminder => 'Reminders';

  @override
  String get typeOverdue => 'Overdue chores';

  @override
  String get typeDismissed => 'Chore dismissed';

  @override
  String get typeSuperseded => 'Chore replaced';

  @override
  String get typeReverted => 'Chore reopened';

  @override
  String get typeMarkedAway => 'Marked away';

  @override
  String get typeInvitation => 'Invitations';

  @override
  String recapTitle(String month) {
    return 'Month recap · $month';
  }

  @override
  String recapWinnerYou(String month, int points) {
    return 'You won $month with $points points!';
  }

  @override
  String recapWinnerOther(String name, String month, int points) {
    return '$name won $month with $points points.';
  }

  @override
  String recapTotal(int total) {
    return 'Together you earned $total points.';
  }

  @override
  String recapNobody(String month) {
    return 'Nobody scored in $month.';
  }

  @override
  String get recapClose => 'Nice!';

  @override
  String switchHousehold(String name) {
    return 'Household $name, switch household';
  }

  @override
  String get householdDetails => 'Household details';

  @override
  String overdueStill(int points) {
    return 'Overdue · still +$points';
  }

  @override
  String revertedBecause(String reason) {
    return 'Reverted: $reason';
  }
}
