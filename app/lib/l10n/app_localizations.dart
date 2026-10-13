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

  /// No description provided for @householdsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your households'**
  String get householdsTitle;

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

  /// No description provided for @templateTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get templateTitle;

  /// No description provided for @openChores.
  ///
  /// In en, this message translates to:
  /// **'Open chores'**
  String get openChores;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @openLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get openLeaderboard;

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

  /// No description provided for @podiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Podium'**
  String get podiumTitle;

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
