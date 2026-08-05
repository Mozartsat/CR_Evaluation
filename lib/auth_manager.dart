import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'employee_repository.dart';

/// Résultat d'une tentative de connexion — permet à l'écran de login
/// d'afficher un message précis (identifiant/mdp faux, compte bloqué,
/// compte désactivé, ou souci réseau), au lieu d'un message générique.
enum AuthResult { succes, echec, bloque, desactive, erreurReseau }

class AuthManager {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String? currentUserID;
  static String currentUserCity = 'PNR';
  static Set<String> currentUserServices = {};
  // 'admin' | 'dex' | 'rep' | 'sup'
  static String currentUserRole = 'rep';
  // id (uuid) du compte en base, nécessaire pour changer son propre mot de
  // passe sans avoir à re-rechercher l'identifiant.
  static String? _currentAccountId;

  static bool get isRep => currentUserRole == 'rep';

  // Rep et Admin peuvent débloquer une évaluation verrouillée (>48h).
  static bool get canUnlockEvaluations =>
      currentUserRole == 'rep' || currentUserRole == 'admin';

  // ============================================================
  //   CONNEXION / DÉCONNEXION
  // ============================================================

  /// Vérifie l'identifiant/mot de passe dans la table Supabase `comptes`.
  /// Un compte bloqué ou désactivé est refusé même si le mot de passe est
  /// correct, avec un résultat distinct pour que l'écran de login puisse
  /// afficher le bon message.
  static Future<AuthResult> login(String id, String pw) async {
    try {
      final row = await _supabase
          .from('comptes')
          .select()
          .eq('identifiant', id)
          .maybeSingle();

      if (row == null || row['mot_de_passe'] != pw) {
        return AuthResult.echec;
      }
      if (row['bloque'] == true) return AuthResult.bloque;
      if (row['actif'] == false) return AuthResult.desactive;

      currentUserID = row['identifiant'] as String;
      currentUserCity = row['ville'] as String;
      currentUserServices =
          Set<String>.from((row['services'] as List?) ?? const []);
      currentUserRole = row['role'] as String;
      _currentAccountId = row['id'] as String;

      // Mise à jour du dernier login — best-effort, ne bloque pas la
      // connexion si ça échoue (et n'échoue jamais bruyamment).
      unawaited(_supabase
          .from('comptes')
          .update({'dernier_login': DateTime.now().toIso8601String()})
          .eq('id', row['id'])
          .then((_) {}, onError: (_) {}));

      unawaited(EmployeeRepository.instance.journaliserActivite(
        action: 'connexion',
        cibleType: 'compte',
        cibleId: _currentAccountId,
        cibleLibelle: currentUserID,
      ));

      return AuthResult.succes;
    } catch (_) {
      return AuthResult.erreurReseau;
    }
  }

  static void logout() {
    if (currentUserID != null) {
      unawaited(EmployeeRepository.instance.journaliserActivite(
        action: 'deconnexion',
        cibleType: 'compte',
        cibleId: _currentAccountId,
        cibleLibelle: currentUserID,
      ));
    }
    currentUserID = null;
    currentUserCity = 'PNR';
    currentUserServices = {};
    currentUserRole = 'rep';
    _currentAccountId = null;
  }

  static bool canSeeCity(String city) {
    if (currentUserID == null) return false;
    if (currentUserCity == 'ALL') return true;
    return currentUserCity == city;
  }

  static bool hasAccess(String label) {
    if (currentUserID == null) return false;
    if (currentUserRole == 'admin') return true;

    final parts = label.split(' : ');
    if (parts.length < 2) return false;
    final segments = parts.last.split(' - ');
    if (segments.length < 2) return false;
    final city = segments.first;
    final service = segments.last;
    return currentUserCity == city && currentUserServices.contains(service);
  }

  // Retourne la juridiction du rep connecté (services + ville)
  static Map<String, dynamic>? get juridiction {
    if (!isRep) return null;
    return {
      'services': currentUserServices.toList(),
      'ville': currentUserCity,
    };
  }

  // ============================================================
  //   MOT DE PASSE
  // ============================================================

  /// Le compte connecté change SON PROPRE mot de passe — l'ancien mot de
  /// passe doit être fourni et vérifié avant d'accepter le changement.
  /// Retourne false si l'ancien mot de passe est incorrect ou en cas
  /// d'erreur réseau.
  static Future<bool> changerMonMotDePasse({
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  }) async {
    if (currentUserID == null || _currentAccountId == null) return false;
    try {
      final row = await _supabase
          .from('comptes')
          .select('mot_de_passe')
          .eq('id', _currentAccountId!)
          .maybeSingle();
      if (row == null || row['mot_de_passe'] != ancienMotDePasse) {
        return false;
      }

      await _supabase
          .from('comptes')
          .update({'mot_de_passe': nouveauMotDePasse}).eq(
              'id', _currentAccountId!);

      unawaited(EmployeeRepository.instance.journaliserActivite(
        action: 'modification',
        cibleType: 'compte',
        cibleId: _currentAccountId,
        cibleLibelle: currentUserID,
        details: {'champ': 'mot_de_passe', 'par': 'lui-même'},
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// ADMIN UNIQUEMENT : change le mot de passe d'un autre compte (pas
  /// besoin de connaître l'ancien — utile pour une récupération/reset).
  static Future<bool> adminChangerMotDePasse({
    required String compteId,
    required String nouveauMotDePasse,
  }) async {
    if (currentUserRole != 'admin') return false;
    try {
      await _supabase
          .from('comptes')
          .update({'mot_de_passe': nouveauMotDePasse}).eq('id', compteId);

      unawaited(EmployeeRepository.instance.journaliserActivite(
        action: 'modification',
        cibleType: 'compte',
        cibleId: compteId,
        details: {'champ': 'mot_de_passe', 'par': currentUserID},
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  //   GESTION DES COMPTES (ADMIN UNIQUEMENT)
  // ============================================================

  static Future<List<Map<String, dynamic>>> listerComptes() async {
    if (currentUserRole != 'admin') return [];
    try {
      final rows =
          await _supabase.from('comptes').select().order('identifiant');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      throw Exception("Erreur de chargement des comptes : $e");
    }
  }

  static Future<void> ajouterCompte({
    required String identifiant,
    required String motDePasse,
    required String role,
    required String ville,
    required List<String> services,
  }) async {
    if (currentUserRole != 'admin') return;
    try {
      await _supabase.from('comptes').insert({
        'identifiant': identifiant,
        'mot_de_passe': motDePasse,
        'role': role,
        'ville': ville,
        'services': services,
        'actif': true,
        'bloque': false,
      });
      unawaited(EmployeeRepository.instance.journaliserActivite(
        action: 'creation',
        cibleType: 'compte',
        cibleLibelle: identifiant,
        ville: ville,
        details: {'role': role, 'services': services},
      ));
    } catch (e) {
      throw Exception("Erreur lors de la création du compte : $e");
    }
  }

  static Future<void> modifierDroitsCompte({
    required String compteId,
    required String identifiantPourJournal,
    required String role,
    required String ville,
    required List<String> services,
  }) async {
    if (currentUserRole != 'admin') return;
    try {
      await _supabase.from('comptes').update({
        'role': role,
        'ville': ville,
        'services': services,
      }).eq('id', compteId);
      unawaited(EmployeeRepository.instance.journaliserActivite(
        action: 'modification',
        cibleType: 'compte',
        cibleId: compteId,
        cibleLibelle: identifiantPourJournal,
        ville: ville,
        details: {'role': role, 'services': services},
      ));
    } catch (e) {
      throw Exception("Erreur lors de la modification du compte : $e");
    }
  }

  static Future<void> definirBlocage({
    required String compteId,
    required String identifiantPourJournal,
    required bool bloque,
  }) async {
    if (currentUserRole != 'admin') return;
    try {
      await _supabase.from('comptes').update({'bloque': bloque}).eq('id', compteId);
      unawaited(EmployeeRepository.instance.journaliserActivite(
        action: bloque ? 'blocage' : 'deblocage',
        cibleType: 'compte',
        cibleId: compteId,
        cibleLibelle: identifiantPourJournal,
      ));
    } catch (e) {
      throw Exception("Erreur lors du blocage/déblocage : $e");
    }
  }

  static Future<void> definirActivation({
    required String compteId,
    required String identifiantPourJournal,
    required bool actif,
  }) async {
    if (currentUserRole != 'admin') return;
    try {
      await _supabase.from('comptes').update({'actif': actif}).eq('id', compteId);
      unawaited(EmployeeRepository.instance.journaliserActivite(
        action: 'modification',
        cibleType: 'compte',
        cibleId: compteId,
        cibleLibelle: identifiantPourJournal,
        details: {'actif': actif},
      ));
    } catch (e) {
      throw Exception("Erreur lors de l'activation/désactivation : $e");
    }
  }

  static Future<void> supprimerCompte({
    required String compteId,
    required String identifiantPourJournal,
  }) async {
    if (currentUserRole != 'admin') return;
    try {
      await _supabase.from('comptes').delete().eq('id', compteId);
      unawaited(EmployeeRepository.instance.journaliserActivite(
        action: 'suppression',
        cibleType: 'compte',
        cibleId: compteId,
        cibleLibelle: identifiantPourJournal,
      ));
    } catch (e) {
      throw Exception("Erreur lors de la suppression du compte : $e");
    }
  }
}