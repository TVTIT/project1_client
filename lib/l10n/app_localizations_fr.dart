// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LFr extends L {
  LFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'SANSLAB IoT Server';

  @override
  String get navOverview => 'Aperçu';

  @override
  String get navManage => 'Gérer';

  @override
  String get navApps => 'Applications';

  @override
  String get navBuild => 'Créer';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navProjects => 'Projets';

  @override
  String get navOrders => 'Commandes';

  @override
  String get navCustomers => 'Clients';

  @override
  String get navProducts => 'Produits';

  @override
  String get navInbox => 'Boîte de réception';

  @override
  String get navBoard => 'Tableau';

  @override
  String get navCalendar => 'Calendrier';

  @override
  String get navChat => 'Discussion';

  @override
  String get navComponents => 'Composants';

  @override
  String get navForms => 'Formulaires';

  @override
  String get navWizard => 'Assistant';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get navProfile => 'Profil';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionRefresh => 'Actualiser';

  @override
  String get actionExport => 'Exporter';

  @override
  String get actionSearch => 'Rechercher';

  @override
  String get actionClear => 'Effacer';

  @override
  String get actionPrevious => 'Précédent';

  @override
  String get actionNext => 'Suivant';

  @override
  String get actionSignIn => 'Se connecter';

  @override
  String get actionSignOut => 'Se déconnecter';

  @override
  String get signInTitle => 'Se connecter';

  @override
  String get signInSubtitle =>
      'N\'importe quel e-mail convient — c\'est le fournisseur simulé.';

  @override
  String get fieldEmail => 'E-mail';

  @override
  String get fieldPassword => 'Mot de passe';

  @override
  String get fieldName => 'Nom';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get noAccount => 'Pas de compte ? Créez-en un';

  @override
  String get lightMode => 'Mode clair';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get language => 'Langue';

  @override
  String get theme => 'Thème';

  @override
  String get accent => 'Accent';

  @override
  String get emptyTitle => 'Aucun résultat pour ces filtres';

  @override
  String get emptyMessage =>
      'Essayez d\'effacer la recherche ou de choisir un autre statut.';

  @override
  String get errorTitle => 'Une erreur est survenue';

  @override
  String get errorRetry => 'Réessayer';

  @override
  String pageOf(int page, int pages) {
    return 'Page $page sur $pages';
  }

  @override
  String rangeOfTotal(int first, int last, int total) {
    return '$first–$last sur $total';
  }

  @override
  String get accountInfo => 'Informations du compte';

  @override
  String get accountSubtitle =>
      'Afficher les détails de l\'identité et de la session active de ce compte.';

  @override
  String get accountIdentityTitle => 'Informations d\'identité';

  @override
  String get accountUserId => 'Identifiant utilisateur (UUID)';

  @override
  String get accountEmail => 'E-mail du compte';

  @override
  String get accountFullName => 'Nom complet';

  @override
  String get accountRole => 'Rôle de passerelle';

  @override
  String get accountRoleUnassigned => 'Aucun rôle assigné';

  @override
  String get accountRoleNote =>
      'Les autorisations sont vérifiées dynamiquement par passerelle sur le backend.';

  @override
  String get accountSessionTitle => 'Session et sécurité';

  @override
  String get accountSessionStatus => 'Statut de la session';

  @override
  String get accountStatusActive => 'Actif';

  @override
  String get accountAuthMethod => 'Méthode d\'authentification';

  @override
  String get accountAuthMethodValue =>
      'Supabase Auth (GoTrue) · Vérification locale HS256';

  @override
  String get accountAdminNoteTitle => 'Politique de gestion des comptes';

  @override
  String get accountAdminNote =>
      'Les comptes sont gérés de manière centralisée par les administrateurs.';

  @override
  String get accountCopyId => 'Copier l\'identifiant';

  @override
  String get accountCopiedId => 'Identifiant copié dans le presse-papier';

  @override
  String get accountBackToDashboard => 'Retour au tableau de bord';

  @override
  String get navGateways => 'Passerelles';

  @override
  String get gatewayListTitle => 'Passerelles';

  @override
  String get gatewayListSubtitle =>
      'Liste des passerelles accessibles sur la plateforme.';

  @override
  String get gatewayId => 'Identifiant passerelle';

  @override
  String get gatewayName => 'Nom';

  @override
  String get gatewayDescription => 'Description';

  @override
  String get gatewayRole => 'Rôle';

  @override
  String get gatewayCreatedAt => 'Date de création';

  @override
  String get gatewaySearchPlaceholder => 'Rechercher par identifiant, nom...';

  @override
  String get gatewayEmptyTitle => 'Aucune passerelle';

  @override
  String get gatewayEmptyMessage =>
      'Votre compte n\'a pas encore accès à des passerelles.';

  @override
  String get gatewaySearchEmptyTitle => 'Aucun résultat';

  @override
  String get gatewaySearchEmptyMessage =>
      'Aucune passerelle ne correspond à votre recherche.';

  @override
  String get gatewayRoleOwner => 'Propriétaire';

  @override
  String get gatewayRoleOperator => 'Opérateur';

  @override
  String get gatewayRoleViewer => 'Lecteur';

  @override
  String get gatewayActionDetail => 'Détails';

  @override
  String get gatewayDetailTitle => 'Détails de la passerelle';

  @override
  String get gatewayDetailSubtitle =>
      'Aperçu de la station et des capteurs associés.';

  @override
  String get gatewayNotFoundTitle => 'Passerelle introuvable';

  @override
  String get gatewayNotFoundMessage =>
      'La passerelle demandée est introuvable ou vous n\'avez pas l\'autorisation d\'accès.';

  @override
  String get gatewayInvalidIdMessage =>
      'Identifiant de passerelle invalide ou réservé.';

  @override
  String get gatewayBackToList => 'Retour aux passerelles';

  @override
  String get gatewaySectionMetadata => 'Informations sur la passerelle';

  @override
  String get gatewaySectionSensors => 'Catalogue des capteurs';

  @override
  String get sensorId => 'ID du capteur';

  @override
  String get sensorName => 'Nom du capteur';

  @override
  String get sensorUnit => 'Unité';

  @override
  String get sensorCreatedAt => 'Date de création';

  @override
  String get sensorEmptyTitle => 'Aucun capteur configuré';

  @override
  String get sensorEmptyMessage =>
      'Aucun capteur n\'a encore été configuré pour cette passerelle.';

  @override
  String get sensorSearchPlaceholder =>
      'Rechercher des capteurs par identifiant, nom ou unité...';

  @override
  String get sensorSearchEmptyTitle => 'Aucun capteur correspondant';

  @override
  String get sensorSearchEmptyMessage =>
      'Aucun capteur ne correspond à votre recherche.';

  @override
  String get sensorErrorTitle => 'Échec du chargement des capteurs';

  @override
  String get sensorErrorRetry => 'Réessayer de charger les capteurs';

  @override
  String get gatewayReadOnlyNotice =>
      'Mode lecture seule (Étape 2). Les commandes à distance ne sont pas actives.';
}
