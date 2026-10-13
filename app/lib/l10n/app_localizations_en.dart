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
  String get householdsTitle => 'Your households';

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
  String get openChores => 'Open chores';
}
