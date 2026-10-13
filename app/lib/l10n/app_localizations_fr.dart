// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'BetterHome';

  @override
  String get householdsTitle => 'Vos foyers';

  @override
  String get householdsEmpty =>
      'Aucun foyer pour l’instant. Créez-en un pour commencer.';

  @override
  String get createHousehold => 'Créer un foyer';

  @override
  String get householdName => 'Nom du foyer';

  @override
  String get timezone => 'Fuseau horaire';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get members => 'Membres';

  @override
  String get invite => 'Inviter';

  @override
  String get inviteEmail => 'E-mail à inviter';

  @override
  String get roleMember => 'Membre';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get sendInvite => 'Envoyer l’invitation';

  @override
  String get inviteCreated => 'Invitation créée';

  @override
  String copyToken(String token) {
    return 'Jeton : $token';
  }

  @override
  String get acceptInvite => 'Accepter une invitation';

  @override
  String get inviteToken => 'Jeton d’invitation';

  @override
  String get leaveHousehold => 'Quitter le foyer';

  @override
  String get setAway => 'Marquer absent';

  @override
  String get clearAway => 'Fin d’absence';

  @override
  String get away => 'Absent';

  @override
  String get syncProfileTitle => 'Votre profil';

  @override
  String get syncProfileSubtitle =>
      'Synchronisez votre compte avec BetterHome avant de rejoindre un foyer.';

  @override
  String get email => 'E-mail';

  @override
  String get givenName => 'Prénom';

  @override
  String get familyName => 'Nom';

  @override
  String get language => 'Langue';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get errorGeneric => 'Une erreur s’est produite';

  @override
  String get retry => 'Réessayer';

  @override
  String get useDemoData => 'Continuer avec des données de démo';

  @override
  String get loading => 'Chargement…';
}
