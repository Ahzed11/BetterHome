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

  @override
  String get choresTitle => 'Tâches';

  @override
  String get allChores => 'Toutes les tâches';

  @override
  String get myChores => 'Mes tâches';

  @override
  String get choresEmpty =>
      'Aucune tâche. Enregistrez quelque chose que vous venez de faire.';

  @override
  String get quickLog => 'Je viens de…';

  @override
  String get completeTask => 'Terminer';

  @override
  String get dismissTask => 'Ignorer';

  @override
  String get dismissConfirmTitle => 'Ignorer cette tâche ?';

  @override
  String get dismissConfirmBody =>
      'L’action est définitive et n’attribue aucun point.';

  @override
  String get createTemplate => 'Nouveau modèle';

  @override
  String get templateTitle => 'Titre';

  @override
  String get leaderboardTitle => 'Classement';

  @override
  String get periodWeek => 'Semaine';

  @override
  String get periodMonth => 'Mois';

  @override
  String get periodYear => 'Année';

  @override
  String get periodAll => 'Tout';

  @override
  String get effortBarTitle => 'Effort partagé';

  @override
  String get hallOfWinners => 'Palmarès';

  @override
  String get leaderboardEmpty => 'Aucun point pour cette période.';

  @override
  String get noWinnersYet => 'Pas encore de gagnants.';

  @override
  String pointsLabel(int points) {
    return '$points pts';
  }

  @override
  String get you => 'Vous';

  @override
  String get revertTask => 'Annuler';

  @override
  String get revertConfirmTitle => 'Annuler cette validation ?';

  @override
  String get revertConfirmBody =>
      'Les points seront retirés. Indiquez une raison.';

  @override
  String get revertReason => 'Raison';

  @override
  String get makeRecurring => 'Rendre récurrente';

  @override
  String get recurrenceDaily => 'Quotidien';

  @override
  String get recurrenceWeekly => 'Hebdomadaire';

  @override
  String get recurrenceMonthly => 'Mensuel';

  @override
  String get runDueNow => 'Générer les tâches dues';

  @override
  String get recurrenceSet => 'Récurrence enregistrée';

  @override
  String spawnedCount(int count) {
    return '$count tâche(s) générée(s)';
  }

  @override
  String get signInTitle => 'Bienvenue sur BetterHome';

  @override
  String get signInSubtitle =>
      'Connectez-vous pour partager tâches, points et listes avec votre foyer.';

  @override
  String get signInButton => 'Se connecter';

  @override
  String get signingIn => 'Connexion…';

  @override
  String get signInFailed => 'La connexion n\'a pas abouti. Réessayez.';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get createList => 'Créer une liste';

  @override
  String get listName => 'Nom de la liste';

  @override
  String get renameList => 'Renommer';

  @override
  String get archiveList => 'Archiver';

  @override
  String get archiveListConfirmTitle => 'Archiver cette liste ?';

  @override
  String get archiveListConfirmBody =>
      'Les listes archivées disparaissent de cet écran et ne peuvent plus être modifiées.';

  @override
  String get itemsEmpty =>
      'Rien ici pour le moment. Ajoutez le premier élément.';

  @override
  String get deleteItem => 'Supprimer l\'élément';

  @override
  String get resetList => 'Tout décocher';

  @override
  String get resetListConfirmTitle => 'Décocher tous les éléments ?';

  @override
  String get resetListConfirmBody =>
      'Pratique pour repartir de zéro, par exemple une liste de valise.';

  @override
  String get listsTitle => 'Listes';

  @override
  String get listsEmpty =>
      'Aucune liste pour le moment. Un admin peut en créer une.';

  @override
  String get newList => 'Nouvelle liste';

  @override
  String get addItem => 'Ajouter un élément';

  @override
  String get addItemHint => 'Ajouter un élément…';

  @override
  String get addItemButton => 'Ajouter';

  @override
  String get basketTitle => 'Dans le panier';

  @override
  String get listOptions => 'Options de la liste';

  @override
  String checkItem(String title) {
    return 'Cocher $title';
  }

  @override
  String uncheckItem(String title) {
    return 'Décocher $title';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'Vous êtes à jour.';

  @override
  String get markAllRead => 'Tout marquer comme lu';

  @override
  String get loadMore => 'Voir plus';

  @override
  String get notificationSettings => 'Réglages des notifications';

  @override
  String get channelPush => 'Notification push';

  @override
  String get channelInApp => 'Dans l\'app';

  @override
  String get notificationsBellUnread => 'Notifications, non lues';

  @override
  String get unreadLabel => 'non lue';

  @override
  String get typeTaskAssigned => 'Nouvelle tâche';

  @override
  String get typeTaskReassigned => 'Tâche qui vous est réattribuée';

  @override
  String get typeDueReminder => 'Rappels';

  @override
  String get typeOverdue => 'Tâches en retard';

  @override
  String get typeDismissed => 'Tâche fermée';

  @override
  String get typeSuperseded => 'Tâche remplacée';

  @override
  String get typeReverted => 'Tâche rouverte';

  @override
  String get typeMarkedAway => 'Absence enregistrée';

  @override
  String get typeInvitation => 'Invitations';

  @override
  String recapTitle(String month) {
    return 'Bilan du mois · $month';
  }

  @override
  String recapWinnerYou(String month, int points) {
    return 'Vous avez remporté $month avec $points points !';
  }

  @override
  String recapWinnerOther(String name, String month, int points) {
    return '$name a remporté $month avec $points points.';
  }

  @override
  String recapTotal(int total) {
    return 'À vous tous, vous avez gagné $total points.';
  }

  @override
  String recapNobody(String month) {
    return 'Personne n’a marqué de points en $month.';
  }

  @override
  String get recapClose => 'Super !';

  @override
  String switchHousehold(String name) {
    return 'Foyer $name, changer de foyer';
  }

  @override
  String get householdDetails => 'Détails du foyer';

  @override
  String overdueStill(int points) {
    return 'En retard · encore +$points';
  }

  @override
  String revertedBecause(String reason) {
    return 'Annulée : $reason';
  }

  @override
  String get undo => 'Annuler';

  @override
  String quickLogPending(String title) {
    return 'Enregistrement de $title…';
  }

  @override
  String get templatesSection => 'Modèles de tâches';

  @override
  String get templatesEmpty =>
      'Aucun modèle pour l\'instant. Ajoutez-en un pour enregistrer des tâches.';

  @override
  String get addTemplate => 'Ajouter un modèle';

  @override
  String get editTemplate => 'Modifier le modèle';

  @override
  String get templateEmoji => 'Émoji (facultatif)';

  @override
  String get templateDescription => 'Description (facultatif)';

  @override
  String get templatePoints => 'Points';

  @override
  String get templateLatePoints => 'Points si en retard';

  @override
  String templatePointsSummary(int points, int latePoints) {
    return '$points pts · $latePoints si en retard';
  }

  @override
  String get templateTitleRequired => 'Saisissez un titre';

  @override
  String get templateNumberInvalid => 'Saisissez un nombre entier, 0 ou plus';

  @override
  String get catchUp => 'À rattraper';

  @override
  String get catchUpHint => 'En retard, rapporte encore des points';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'dans $days jours',
      one: 'demain',
      zero: 'aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String get noDueDate => 'Sans échéance';

  @override
  String get choresDone => 'Terminées';

  @override
  String filterAll(int count) {
    return 'Toutes · $count';
  }

  @override
  String filterMine(int count) {
    return 'Mes tâches · $count';
  }

  @override
  String get filterDone => 'Terminées';

  @override
  String get householdEyebrow => 'Foyer';

  @override
  String get podiumRoom => 'De la place pour un de plus';

  @override
  String effortTogether(int points) {
    return '$points pts ensemble';
  }

  @override
  String get inviteHousemate => 'Inviter un colocataire';

  @override
  String householdSummary(int count, String timezone) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0 · $timezone';
  }

  @override
  String get yourChores => 'Vos tâches';

  @override
  String heyHousehold(String name, String household) {
    return 'Salut $name · $household';
  }

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String rankBehind(int rank, int behind) {
    return 'n°$rank · $behind de retard';
  }

  @override
  String get rankFirst => 'n°1 · en tête';

  @override
  String withinReach(int points, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches restantes',
      one: 'une tâche restante',
      zero: 'plus rien à faire',
    );
    return '$points pts à portée cette semaine — $_temp0.';
  }

  @override
  String get quickLogSubtitle =>
      'Un tap et c’est noté. Tous les points, pour vous.';

  @override
  String get searchChores => 'Rechercher une tâche';

  @override
  String get quickLogFootnote => 'Ne change pas les tâches prévues des autres.';

  @override
  String get close => 'Fermer';
}
