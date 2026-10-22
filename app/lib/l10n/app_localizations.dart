import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BetterHome'**
  String get appTitle;

  /// No description provided for @householdsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No households yet. Create one to get started.'**
  String get householdsEmpty;

  /// No description provided for @createHousehold.
  ///
  /// In en, this message translates to:
  /// **'Create household'**
  String get createHousehold;

  /// No description provided for @householdName.
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get householdName;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @inviteEmail.
  ///
  /// In en, this message translates to:
  /// **'Email to invite'**
  String get inviteEmail;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @sendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get sendInvite;

  /// No description provided for @inviteCreated.
  ///
  /// In en, this message translates to:
  /// **'Invitation created'**
  String get inviteCreated;

  /// No description provided for @copyToken.
  ///
  /// In en, this message translates to:
  /// **'Token: {token}'**
  String copyToken(String token);

  /// No description provided for @acceptInvite.
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get acceptInvite;

  /// No description provided for @inviteToken.
  ///
  /// In en, this message translates to:
  /// **'Invitation token'**
  String get inviteToken;

  /// No description provided for @leaveHousehold.
  ///
  /// In en, this message translates to:
  /// **'Leave household'**
  String get leaveHousehold;

  /// No description provided for @setAway.
  ///
  /// In en, this message translates to:
  /// **'Mark away'**
  String get setAway;

  /// No description provided for @clearAway.
  ///
  /// In en, this message translates to:
  /// **'Clear away'**
  String get clearAway;

  /// No description provided for @away.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get away;

  /// No description provided for @syncProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get syncProfileTitle;

  /// No description provided for @syncProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your account with BetterHome before joining a household.'**
  String get syncProfileSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @givenName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get givenName;

  /// No description provided for @familyName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get familyName;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @useDemoData.
  ///
  /// In en, this message translates to:
  /// **'Continue with demo data'**
  String get useDemoData;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @choresTitle.
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get choresTitle;

  /// No description provided for @allChores.
  ///
  /// In en, this message translates to:
  /// **'All chores'**
  String get allChores;

  /// No description provided for @myChores.
  ///
  /// In en, this message translates to:
  /// **'My chores'**
  String get myChores;

  /// No description provided for @choresEmpty.
  ///
  /// In en, this message translates to:
  /// **'No chores yet. Quick-log something you just did.'**
  String get choresEmpty;

  /// No description provided for @quickLog.
  ///
  /// In en, this message translates to:
  /// **'I just did…'**
  String get quickLog;

  /// No description provided for @completeTask.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get completeTask;

  /// No description provided for @dismissTask.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissTask;

  /// No description provided for @dismissConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Dismiss this chore?'**
  String get dismissConfirmTitle;

  /// No description provided for @dismissConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Dismissal is permanent and awards no points.'**
  String get dismissConfirmBody;

  /// No description provided for @createTemplate.
  ///
  /// In en, this message translates to:
  /// **'New chore template'**
  String get createTemplate;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// No description provided for @periodAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get periodAll;

  /// No description provided for @effortBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared effort'**
  String get effortBarTitle;

  /// No description provided for @hallOfWinners.
  ///
  /// In en, this message translates to:
  /// **'Hall of winners'**
  String get hallOfWinners;

  /// No description provided for @leaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No points yet this period.'**
  String get leaderboardEmpty;

  /// No description provided for @noWinnersYet.
  ///
  /// In en, this message translates to:
  /// **'No past winners yet.'**
  String get noWinnersYet;

  /// No description provided for @pointsLabel.
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String pointsLabel(int points);

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @revertTask.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get revertTask;

  /// No description provided for @revertConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Revert this completion?'**
  String get revertConfirmTitle;

  /// No description provided for @revertConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Points will be reversed. Please give a reason.'**
  String get revertConfirmBody;

  /// No description provided for @revertReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get revertReason;

  /// No description provided for @makeRecurring.
  ///
  /// In en, this message translates to:
  /// **'Make recurring'**
  String get makeRecurring;

  /// No description provided for @recurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurrenceMonthly;

  /// No description provided for @runDueNow.
  ///
  /// In en, this message translates to:
  /// **'Spawn due chores'**
  String get runDueNow;

  /// No description provided for @recurrenceSet.
  ///
  /// In en, this message translates to:
  /// **'Recurrence saved'**
  String get recurrenceSet;

  /// No description provided for @spawnedCount.
  ///
  /// In en, this message translates to:
  /// **'Spawned {count} chore(s)'**
  String spawnedCount(int count);

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to BetterHome'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to share chores, points and lists with your home.'**
  String get signInSubtitle;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in did not complete. Try again.'**
  String get signInFailed;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @serverSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to your server'**
  String get serverSetupTitle;

  /// No description provided for @serverSetupBody.
  ///
  /// In en, this message translates to:
  /// **'BetterHome runs on a server that you or a housemate host. Enter its address to sign in.'**
  String get serverSetupBody;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @serverAddressHint.
  ///
  /// In en, this message translates to:
  /// **'https://home.example.com'**
  String get serverAddressHint;

  /// No description provided for @serverChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get serverChecking;

  /// No description provided for @serverInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a web address, such as https://home.example.com'**
  String get serverInvalid;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'No BetterHome server answered at this address. Check it and your connection.'**
  String get serverUnreachable;

  /// No description provided for @serverChange.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get serverChange;

  /// No description provided for @serverCurrent.
  ///
  /// In en, this message translates to:
  /// **'Server: {host}'**
  String serverCurrent(String host);

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountIntro.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account removes your name and email and signs you out for good. You leave every household; one where you are the only member is deleted with you.'**
  String get deleteAccountIntro;

  /// No description provided for @deleteAccountHistory.
  ///
  /// In en, this message translates to:
  /// **'What you did stays in your households, such as completed chores and points, but no longer carries your name.'**
  String get deleteAccountHistory;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountSoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'You are the only admin of a household that has other members. Make another member an admin, or delete the household, then try again.'**
  String get deleteAccountSoleAdmin;

  /// No description provided for @createList.
  ///
  /// In en, this message translates to:
  /// **'Create list'**
  String get createList;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get listName;

  /// No description provided for @renameList.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameList;

  /// No description provided for @archiveList.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveList;

  /// No description provided for @archiveListConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this list?'**
  String get archiveListConfirmTitle;

  /// No description provided for @archiveListConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Archived lists disappear from this screen and can no longer be changed.'**
  String get archiveListConfirmBody;

  /// No description provided for @itemsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Add the first item.'**
  String get itemsEmpty;

  /// No description provided for @deleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get deleteItem;

  /// No description provided for @resetList.
  ///
  /// In en, this message translates to:
  /// **'Uncheck all'**
  String get resetList;

  /// No description provided for @resetListConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Uncheck every item?'**
  String get resetListConfirmTitle;

  /// No description provided for @resetListConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Use this to start the list over, for example a packing list.'**
  String get resetListConfirmBody;

  /// No description provided for @listsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get listsTitle;

  /// No description provided for @listsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No lists yet. An admin can create one.'**
  String get listsEmpty;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newList;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get addItem;

  /// No description provided for @addItemHint.
  ///
  /// In en, this message translates to:
  /// **'Add an item…'**
  String get addItemHint;

  /// No description provided for @addItemButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addItemButton;

  /// No description provided for @basketTitle.
  ///
  /// In en, this message translates to:
  /// **'In the basket'**
  String get basketTitle;

  /// No description provided for @checkItem.
  ///
  /// In en, this message translates to:
  /// **'Check {title}'**
  String checkItem(String title);

  /// No description provided for @uncheckItem.
  ///
  /// In en, this message translates to:
  /// **'Uncheck {title}'**
  String uncheckItem(String title);

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get notificationsEmpty;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettings;

  /// No description provided for @channelPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get channelPush;

  /// No description provided for @channelInApp.
  ///
  /// In en, this message translates to:
  /// **'In the app'**
  String get channelInApp;

  /// No description provided for @notificationsBellUnread.
  ///
  /// In en, this message translates to:
  /// **'Notifications, unread'**
  String get notificationsBellUnread;

  /// No description provided for @unreadLabel.
  ///
  /// In en, this message translates to:
  /// **'unread'**
  String get unreadLabel;

  /// No description provided for @typeTaskAssigned.
  ///
  /// In en, this message translates to:
  /// **'New chore'**
  String get typeTaskAssigned;

  /// No description provided for @typeTaskReassigned.
  ///
  /// In en, this message translates to:
  /// **'Chore reassigned to you'**
  String get typeTaskReassigned;

  /// No description provided for @typeDueReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get typeDueReminder;

  /// No description provided for @typeOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue chores'**
  String get typeOverdue;

  /// No description provided for @typeDismissed.
  ///
  /// In en, this message translates to:
  /// **'Chore dismissed'**
  String get typeDismissed;

  /// No description provided for @typeSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Chore replaced'**
  String get typeSuperseded;

  /// No description provided for @typeReverted.
  ///
  /// In en, this message translates to:
  /// **'Chore reopened'**
  String get typeReverted;

  /// No description provided for @typeMarkedAway.
  ///
  /// In en, this message translates to:
  /// **'Marked away'**
  String get typeMarkedAway;

  /// No description provided for @typeInvitation.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get typeInvitation;

  /// No description provided for @recapTitle.
  ///
  /// In en, this message translates to:
  /// **'Month recap · {month}'**
  String recapTitle(String month);

  /// No description provided for @recapWinnerYou.
  ///
  /// In en, this message translates to:
  /// **'You won {month} with {points} points!'**
  String recapWinnerYou(String month, int points);

  /// No description provided for @recapWinnerOther.
  ///
  /// In en, this message translates to:
  /// **'{name} won {month} with {points} points.'**
  String recapWinnerOther(String name, String month, int points);

  /// No description provided for @recapTotal.
  ///
  /// In en, this message translates to:
  /// **'Together you earned {total} points.'**
  String recapTotal(int total);

  /// No description provided for @recapNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody scored in {month}.'**
  String recapNobody(String month);

  /// No description provided for @recapClose.
  ///
  /// In en, this message translates to:
  /// **'Nice!'**
  String get recapClose;

  /// No description provided for @switchHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household {name}, switch household'**
  String switchHousehold(String name);

  /// No description provided for @householdDetails.
  ///
  /// In en, this message translates to:
  /// **'Household details'**
  String get householdDetails;

  /// No description provided for @overdueStill.
  ///
  /// In en, this message translates to:
  /// **'Overdue · still +{points}'**
  String overdueStill(int points);

  /// No description provided for @revertedBecause.
  ///
  /// In en, this message translates to:
  /// **'Reverted: {reason}'**
  String revertedBecause(String reason);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @quickLogPending.
  ///
  /// In en, this message translates to:
  /// **'Logging {title}…'**
  String quickLogPending(String title);

  /// No description provided for @templatesSection.
  ///
  /// In en, this message translates to:
  /// **'Chore templates'**
  String get templatesSection;

  /// No description provided for @templatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No templates yet. Add one to start logging chores.'**
  String get templatesEmpty;

  /// No description provided for @addTemplate.
  ///
  /// In en, this message translates to:
  /// **'Add a template'**
  String get addTemplate;

  /// No description provided for @editTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit template'**
  String get editTemplate;

  /// No description provided for @templatePointsSummary.
  ///
  /// In en, this message translates to:
  /// **'{points} pts · {latePoints} if late'**
  String templatePointsSummary(int points, int latePoints);

  /// No description provided for @catchUp.
  ///
  /// In en, this message translates to:
  /// **'Catch up'**
  String get catchUp;

  /// No description provided for @catchUpHint.
  ///
  /// In en, this message translates to:
  /// **'Late, still worth points'**
  String get catchUpHint;

  /// No description provided for @dueInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{today} =1{tomorrow} other{in {days} days}}'**
  String dueInDays(int days);

  /// No description provided for @noDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get noDueDate;

  /// No description provided for @choresDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get choresDone;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All · {count}'**
  String filterAll(int count);

  /// No description provided for @filterMine.
  ///
  /// In en, this message translates to:
  /// **'Mine · {count}'**
  String filterMine(int count);

  /// No description provided for @filterDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get filterDone;

  /// No description provided for @householdEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get householdEyebrow;

  /// No description provided for @podiumRoom.
  ///
  /// In en, this message translates to:
  /// **'Room for one more'**
  String get podiumRoom;

  /// No description provided for @effortTogether.
  ///
  /// In en, this message translates to:
  /// **'{points} pts together'**
  String effortTogether(int points);

  /// No description provided for @inviteHousemate.
  ///
  /// In en, this message translates to:
  /// **'Invite a housemate'**
  String get inviteHousemate;

  /// No description provided for @householdSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}} · {timezone}'**
  String householdSummary(int count, String timezone);

  /// No description provided for @yourChores.
  ///
  /// In en, this message translates to:
  /// **'Your chores'**
  String get yourChores;

  /// No description provided for @heyHousehold.
  ///
  /// In en, this message translates to:
  /// **'Hey {name} · {household}'**
  String heyHousehold(String name, String household);

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @rankBehind.
  ///
  /// In en, this message translates to:
  /// **'#{rank} · {behind} behind'**
  String rankBehind(int rank, int behind);

  /// No description provided for @rankFirst.
  ///
  /// In en, this message translates to:
  /// **'#1 · in front'**
  String get rankFirst;

  /// No description provided for @withinReach.
  ///
  /// In en, this message translates to:
  /// **'{points} pts within reach this week — {count, plural, =0{nothing left} =1{one chore left} other{{count} chores left}}.'**
  String withinReach(int points, int count);

  /// No description provided for @quickLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One tap logs it. Full points, straight to you.'**
  String get quickLogSubtitle;

  /// No description provided for @searchChores.
  ///
  /// In en, this message translates to:
  /// **'Search chores'**
  String get searchChores;

  /// No description provided for @quickLogFootnote.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t change anyone\'s scheduled chores.'**
  String get quickLogFootnote;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @newRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'New recurring chore'**
  String get newRecurringTitle;

  /// No description provided for @newRecurringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set it once — the household takes turns from there.'**
  String get newRecurringSubtitle;

  /// No description provided for @adminsOnly.
  ///
  /// In en, this message translates to:
  /// **'Admins only'**
  String get adminsOnly;

  /// No description provided for @choreIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get choreIcon;

  /// No description provided for @chooseEmoji.
  ///
  /// In en, this message translates to:
  /// **'Choose an emoji, current: {emoji}'**
  String chooseEmoji(String emoji);

  /// No description provided for @choreName.
  ///
  /// In en, this message translates to:
  /// **'Chore name'**
  String get choreName;

  /// No description provided for @choreNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes — optional'**
  String get choreNotes;

  /// No description provided for @pointsSection.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get pointsSection;

  /// No description provided for @onTimePoints.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get onTimePoints;

  /// No description provided for @latePointsLabel.
  ///
  /// In en, this message translates to:
  /// **'If late, still'**
  String get latePointsLabel;

  /// No description provided for @fewerPoints.
  ///
  /// In en, this message translates to:
  /// **'Fewer {what}'**
  String fewerPoints(String what);

  /// No description provided for @morePoints.
  ///
  /// In en, this message translates to:
  /// **'More {what}'**
  String morePoints(String what);

  /// No description provided for @pointsRule.
  ///
  /// In en, this message translates to:
  /// **'Late points never go above on-time points, and no one ever loses points.'**
  String get pointsRule;

  /// No description provided for @whenSection.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get whenSection;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @intervalDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String intervalDays(int count);

  /// No description provided for @intervalWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String intervalWeeks(int count);

  /// No description provided for @intervalMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String intervalMonths(int count);

  /// No description provided for @decreaseInterval.
  ///
  /// In en, this message translates to:
  /// **'Decrease interval'**
  String get decreaseInterval;

  /// No description provided for @increaseInterval.
  ///
  /// In en, this message translates to:
  /// **'Increase interval'**
  String get increaseInterval;

  /// No description provided for @onDays.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get onDays;

  /// No description provided for @monthlyHint.
  ///
  /// In en, this message translates to:
  /// **'On the 1st of the month.'**
  String get monthlyHint;

  /// No description provided for @whoSection.
  ///
  /// In en, this message translates to:
  /// **'Who does it'**
  String get whoSection;

  /// No description provided for @takeTurns.
  ///
  /// In en, this message translates to:
  /// **'Take turns'**
  String get takeTurns;

  /// No description provided for @takeTurnsHint.
  ///
  /// In en, this message translates to:
  /// **'Rotates fairly between members'**
  String get takeTurnsHint;

  /// No description provided for @onePerson.
  ///
  /// In en, this message translates to:
  /// **'One person'**
  String get onePerson;

  /// No description provided for @onePersonHint.
  ///
  /// In en, this message translates to:
  /// **'Always the same member'**
  String get onePersonHint;

  /// No description provided for @saveChore.
  ///
  /// In en, this message translates to:
  /// **'Save chore'**
  String get saveChore;

  /// No description provided for @stripDayLabel.
  ///
  /// In en, this message translates to:
  /// **'{date}, {count, plural, =0{no chores} =1{1 chore} other{{count} chores}}'**
  String stripDayLabel(String date, int count);

  /// No description provided for @stripToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get stripToday;

  /// No description provided for @thisWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeekLabel;

  /// No description provided for @dayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this day.'**
  String get dayEmpty;

  /// No description provided for @noEmoji.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get noEmoji;

  /// No description provided for @templateFormSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Templates feed the quick log and the recurring chores.'**
  String get templateFormSubtitle;

  /// No description provided for @saveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save template'**
  String get saveTemplate;

  /// No description provided for @pickEmojiTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an icon'**
  String get pickEmojiTitle;

  /// No description provided for @noIcon.
  ///
  /// In en, this message translates to:
  /// **'No icon'**
  String get noIcon;

  /// No description provided for @emojiCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get emojiCleaning;

  /// No description provided for @emojiKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get emojiKitchen;

  /// No description provided for @emojiHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get emojiHome;

  /// No description provided for @emojiLaundry.
  ///
  /// In en, this message translates to:
  /// **'Laundry'**
  String get emojiLaundry;

  /// No description provided for @emojiOutdoors.
  ///
  /// In en, this message translates to:
  /// **'Garden and pets'**
  String get emojiOutdoors;

  /// No description provided for @emojiErrands.
  ///
  /// In en, this message translates to:
  /// **'Errands'**
  String get emojiErrands;

  /// No description provided for @recurringToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Repeats on a schedule'**
  String get recurringToggleTitle;

  /// No description provided for @recurringToggleHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on for a chore that comes back by itself.'**
  String get recurringToggleHint;

  /// No description provided for @houseRules.
  ///
  /// In en, this message translates to:
  /// **'House rules'**
  String get houseRules;

  /// No description provided for @choresAndRotations.
  ///
  /// In en, this message translates to:
  /// **'Chores & rotations'**
  String get choresAndRotations;

  /// No description provided for @choresAndRotationsHint.
  ///
  /// In en, this message translates to:
  /// **'Add a recurring chore'**
  String get choresAndRotationsHint;

  /// No description provided for @taskStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskStatusOpen;

  /// No description provided for @taskStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStatusDone;

  /// No description provided for @taskStatusDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get taskStatusDismissed;

  /// No description provided for @taskStatusReverted.
  ///
  /// In en, this message translates to:
  /// **'Reverted'**
  String get taskStatusReverted;

  /// No description provided for @taskStatusWithPoints.
  ///
  /// In en, this message translates to:
  /// **'{status} · {points}'**
  String taskStatusWithPoints(String status, String points);

  /// No description provided for @unknownMember.
  ///
  /// In en, this message translates to:
  /// **'Household member'**
  String get unknownMember;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
