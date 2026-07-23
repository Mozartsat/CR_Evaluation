import 'package:supabase_flutter/supabase_flutter.dart';
// AJOUTER tout en haut, avant la classe EmployeeRepository
class SupabaseUnavailableException implements Exception {
  final String message;
  SupabaseUnavailableException(this.message);
  @override
  String toString() => message;
}

/// Résultat de l'enregistrement contrôlé d'une évaluation (recalage / quota).
enum ResultatEnregistrementEvaluation {
  /// Nouvelle évaluation insérée normalement.
  insere,
  /// Recalage : la nouvelle note était plus haute, elle remplace l'ancienne du jour.
  recalageNouvelleNoteConservee,
  /// Recalage : la note déjà existante ce jour était plus haute ou égale, rien n'est changé.
  recalageAncienneNoteConservee,
  /// Agent déjà au quota mensuel de jours évalués : cette évaluation est ignorée.
  quotaAtteintIgnore,
}


class EmployeeRepository {
  // Instance Supabase
  final SupabaseClient _supabase = Supabase.instance.client;
  
  static final EmployeeRepository instance = EmployeeRepository._internal();
  EmployeeRepository._internal();

  // Liste locale synchronisée pour l'UI
  final List<Map<String, dynamic>> employees = [];

  /// Initialise les données en récupérant les agents et leurs évaluations depuis Supabase
  Future<void> init() async {
    try {
      // Récupère les agents et inclut les évaluations liées (jointure)
      final List<dynamic> response = await _supabase
          .from('agents')
          .select('*, evaluations(*)');

      employees
        ..clear()
        ..addAll(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      
      // Optionnel : charger des données par défaut si la connexion échoue
    }
  }





  /// Filtre les employés par ville et service (lecture locale après init)
  List<Map<String, dynamic>> getByCityService(String city, String service) {
    return employees
        .where((e) => e['ville'] == city && e['service'] == service)
        .toList();
  }

   /// Vérifie si un agent avec le même nom+prénom existe déjà (ville/service confondus)
  /// excludeId permet d'ignorer l'agent lui-même lors d'une modification
  bool employeeExists(String nom, String prenom, {String? excludeId}) {
    final nomN = nom.trim().toLowerCase();
    final prenomN = prenom.trim().toLowerCase();
    return employees.any((e) =>
        (e['nom'] ?? '').toString().trim().toLowerCase() == nomN &&
        (e['prenom'] ?? '').toString().trim().toLowerCase() == prenomN &&
        (excludeId == null || e['id'] != excludeId));
  }

  /// Ajoute un nouvel agent dans Supabase
 // Dans employee_repository.dart
Future<void> addEmployee(Map<String, dynamic> employee) async {
  try {
    await _supabase.from('agents').insert({
      'nom': employee['nom'],
      'prenom': employee['prenom'],
      'service': employee['service'],
      'ville': employee['ville'],
      'fonction': employee['fonction'],
      'date_embauche': employee['dateEmbauche'],
      'genre': employee['genre'],
    });
    await init();
  } catch (e) {
    
    throw SupabaseUnavailableException(
        "Impossible d'ajouter l'agent.\nVérifiez votre connexion Internet.");
  }
}


  /// Enregistre une nouvelle évaluation avec le décorticage JSONB
  Future<void> enregistrerEvaluation({
  required String agentId,
  required double scoreTotal,
  required List<Map<String, dynamic>> items,
  String? commentaire,
  String? evaluateur,
  String? vacation,          // ← AJOUTER : vacation de la session
  DateTime? dateEvaluation,  // ← AJOUTER : date visée (peut être antidatée)
}) async {
  try {
    await _supabase.from('evaluations').insert({
      'agent_id': agentId,
      'score': scoreTotal,
      'commentaire': commentaire ?? '',
      'items_evalues': items,
      'evaluateur': evaluateur ?? '',
      'vacation': vacation ?? '',
      'date_evaluation': (dateEvaluation ?? DateTime.now())
          .toIso8601String()
          .substring(0, 10),
    });
  } catch (e) {
    throw Exception("Erreur d'enregistrement de l'évaluation : $e");
  }
}

  /// Recherche des évaluations existantes (pour modification par un sup, ou
  /// consultation par un Rep/DEX/Admin en vue d'un déblocage).
  /// Tous les filtres sont optionnels et combinables.
  Future<List<Map<String, dynamic>>> rechercherEvaluations({
    required String ville,
    String? service,
    String? vacation,
    String? evaluateur,
    DateTime? date,
  }) async {
    try {
      dynamic query = _supabase
          .from('evaluations')
          .select('*, agents!inner(id, nom, prenom, fonction, ville, service)')
          .eq('agents.ville', ville);

      if (service != null && service.isNotEmpty) {
        query = query.eq('agents.service', service);
      }
      if (vacation != null && vacation.isNotEmpty) {
        query = query.ilike('vacation', '%$vacation%');
      }
      if (evaluateur != null && evaluateur.isNotEmpty) {
        query = query.ilike('evaluateur', '%$evaluateur%');
      }
      if (date != null) {
        final iso = date.toIso8601String().substring(0, 10);
        query = query.eq('date_evaluation', iso);
      }

      final List<dynamic> response =
          await query.order('date_evaluation', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Erreur de recherche des évaluations : $e");
    }
  }

  /// Modifie le score/les critères d'une évaluation déjà enregistrée.
  /// Le contrôle des 48h / du déblocage doit être fait par l'appelant
  /// AVANT d'appeler cette méthode (voir estDebloque).
  Future<void> modifierEvaluation({
    required String evaluationId,
    required double scoreTotal,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await _supabase.from('evaluations').update({
        'score': scoreTotal,
        'items_evalues': items,
      }).eq('id', evaluationId);
    } catch (e) {
      throw Exception("Erreur de modification de l'évaluation : $e");
    }
  }

  /// Crée un déblocage temporaire (accordé par un Rep, un DEX ou un Admin)
  /// pour une ville + service + date cible, éventuellement restreint à une
  /// vacation précise. Par défaut valide 24h après sa création.
  Future<void> creerDeblocage({
    required String ville,
    required String service,
    required DateTime dateCible,
    String? vacation,
    required String debloquePar,
    Duration validite = const Duration(hours: 24),
  }) async {
    try {
      await _supabase.from('deblocages_evaluation').insert({
        'ville': ville,
        'service': service,
        'date_cible': dateCible.toIso8601String().substring(0, 10),
        'vacation': (vacation == null || vacation.trim().isEmpty)
            ? null
            : vacation.trim(),
        'debloque_par': debloquePar,
        'expire_le': DateTime.now().add(validite).toIso8601String(),
      });
    } catch (e) {
      throw Exception("Erreur lors du déblocage : $e");
    }
  }

  /// Liste les déblocages actifs (non expirés) pour une ville/service donnés,
  /// utilisé par l'écran de déblocage pour afficher l'historique récent.
  Future<List<Map<String, dynamic>>> listerDeblocagesActifs({
    required String ville,
    required String service,
  }) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      final List<dynamic> response = await _supabase
          .from('deblocages_evaluation')
          .select()
          .eq('ville', ville)
          .eq('service', service)
          .gt('expire_le', nowIso)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Annule (bloque de nouveau) un déblocage actif avant son expiration
  /// naturelle. Utilisé par Rep/DEX/Admin pour reverrouiller une évaluation
  /// ou une date qu'ils avaient débloquée par erreur ou trop tôt.
  Future<void> annulerDeblocage(String id) async {
    try {
      await _supabase.from('deblocages_evaluation').delete().eq('id', id);
    } catch (e) {
      throw Exception("Erreur lors du blocage : $e");
    }
  }

  /// Vérifie s'il existe un déblocage actif couvrant cette date
  /// (et éventuellement cette vacation précise) pour ce service/ville.
  /// Regroupe les évaluations par "session" (même date + vacation + évaluateur)
  /// afin qu'un Rep/Admin puisse retrouver et supprimer une session complète.
  /// Filtrage possible par date et/ou évaluateur (au moins un des deux doit
  /// être renseigné côté appelant pour une recherche utile, mais ce n'est
  /// pas imposé ici).
  Future<List<Map<String, dynamic>>> rechercherSessionsEvaluation({
    required String ville,
    String? service,
    DateTime? date,
    String? evaluateur,
  }) async {
    try {
      dynamic query = _supabase
          .from('evaluations')
          .select('*, agents!inner(id, nom, prenom, fonction, ville, service)')
          .eq('agents.ville', ville);

      if (service != null && service.isNotEmpty) {
        query = query.eq('agents.service', service);
      }
      if (evaluateur != null && evaluateur.isNotEmpty) {
        query = query.ilike('evaluateur', '%$evaluateur%');
      }
      if (date != null) {
        final iso = date.toIso8601String().substring(0, 10);
        query = query.eq('date_evaluation', iso);
      }

      final List<dynamic> response =
          await query.order('date_evaluation', ascending: false);
      final rows = List<Map<String, dynamic>>.from(response);

      // Regroupement côté client par (date_evaluation, vacation, évaluateur).
      final Map<String, Map<String, dynamic>> sessions = {};
      for (final row in rows) {
        final d = (row['date_evaluation'] ?? '').toString();
        final v = (row['vacation'] ?? '').toString();
        final e = (row['evaluateur'] ?? '').toString();
        final key = '$d|$v|$e';

        sessions.putIfAbsent(key, () => {
              'date_evaluation': d,
              'vacation': v,
              'evaluateur': e,
              'evaluation_ids': <String>[],
              'agents': <Map<String, dynamic>>[],
            });

        (sessions[key]!['evaluation_ids'] as List<String>)
            .add(row['id'].toString());

        final rawAgent = row['agents'];
        Map<String, dynamic>? agent;
        if (rawAgent is List && rawAgent.isNotEmpty) {
          agent = Map<String, dynamic>.from(rawAgent.first as Map);
        } else if (rawAgent is Map) {
          agent = Map<String, dynamic>.from(rawAgent);
        }
        if (agent != null) {
          (sessions[key]!['agents'] as List<Map<String, dynamic>>).add(agent);
        }
      }

      final list = sessions.values.toList();
      list.sort((a, b) =>
          (b['date_evaluation'] as String).compareTo(a['date_evaluation'] as String));
      return list;
    } catch (e) {
      throw Exception("Erreur de recherche des sessions : $e");
    }
  }

  /// Supprime définitivement toutes les évaluations d'une session
  /// (identifiants obtenus via rechercherSessionsEvaluation).
  Future<void> supprimerSessionEvaluation(List<String> evaluationIds) async {
    if (evaluationIds.isEmpty) return;
    try {
      await _supabase.from('evaluations').delete().inFilter('id', evaluationIds);
    } catch (e) {
      throw Exception("Erreur de suppression de la session : $e");
    }
  }

  // ============================================================
  //   QUOTA MENSUEL DE JOURS D'ÉVALUATION (DEX / Rep / Admin)
  // ============================================================

  static const String _cleQuota = 'max_jours_evaluation_mensuel';

  /// Récupère le quota actuel (nombre de jours d'évaluation autorisés par
  /// agent et par mois). null = pas de limite configurée.
  Future<Map<String, dynamic>?> getParametreQuota() async {
    try {
      final row = await _supabase
          .from('parametres_systeme')
          .select()
          .eq('cle', _cleQuota)
          .maybeSingle();
      return row;
    } catch (e) {
      return null;
    }
  }

  Future<int?> getMaxJoursEvaluation() async {
    final row = await getParametreQuota();
    if (row == null) return null;
    return int.tryParse(row['valeur'].toString());
  }

  /// Définit le quota mensuel de jours d'évaluation par agent.
  Future<void> setMaxJoursEvaluation(int valeur, String modifiePar) async {
    try {
      await _supabase.from('parametres_systeme').upsert({
        'cle': _cleQuota,
        'valeur': valeur.toString(),
        'modifie_par': modifiePar,
        'modifie_le': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("Erreur lors de la mise à jour du quota : $e");
    }
  }

  /// Supprime le quota (repasse en illimité).
  Future<void> supprimerQuota() async {
    try {
      await _supabase.from('parametres_systeme').delete().eq('cle', _cleQuota);
    } catch (e) {
      throw Exception("Erreur lors de la suppression du quota : $e");
    }
  }

  /// Nombre de jours DISTINCTS déjà évalués pour un agent, dans le mois
  /// calendaire de [date].
  Future<int> compterJoursEvaluesDuMois(String agentId, DateTime date) async {
    try {
      final premierJour = DateTime(date.year, date.month, 1);
      final dernierJour = DateTime(date.year, date.month + 1, 0);
      final rows = await _supabase
          .from('evaluations')
          .select('date_evaluation')
          .eq('agent_id', agentId)
          .gte('date_evaluation', premierJour.toIso8601String().substring(0, 10))
          .lte('date_evaluation', dernierJour.toIso8601String().substring(0, 10));

      final joursUniques = <String>{};
      for (final r in rows) {
        final d = r['date_evaluation'];
        if (d != null) joursUniques.add(d.toString());
      }
      return joursUniques.length;
    } catch (e) {
      return 0;
    }
  }

  /// Parmi une liste d'agents, retourne les identifiants de ceux ayant déjà
  /// au moins une évaluation à cette date précise (candidats au recalage).
  Future<List<String>> agentsDejaEvaluesCeJour({
    required List<String> agentIds,
    required DateTime date,
  }) async {
    if (agentIds.isEmpty) return [];
    try {
      final iso = date.toIso8601String().substring(0, 10);
      final rows = await _supabase
          .from('evaluations')
          .select('agent_id')
          .inFilter('agent_id', agentIds)
          .eq('date_evaluation', iso);
      return rows.map((r) => r['agent_id'].toString()).toSet().toList();
    } catch (e) {
      return [];
    }
  }

  /// Enregistre une évaluation en appliquant automatiquement les règles :
  /// - Recalage (2 évaluations le même jour pour le même agent) : seule la
  ///   meilleure note du jour est conservée, l'autre est supprimée.
  /// - Quota mensuel : si l'agent a déjà atteint le nombre de jours
  ///   d'évaluation autorisés ce mois-ci ET que cette date est un nouveau
  ///   jour pour lui, l'évaluation est ignorée (non enregistrée).
  Future<ResultatEnregistrementEvaluation> enregistrerEvaluationControlee({
    required String agentId,
    required double scoreTotal,
    required List<Map<String, dynamic>> items,
    String? commentaire,
    String? evaluateur,
    String? vacation,
    required DateTime dateEvaluation,
  }) async {
    final iso = dateEvaluation.toIso8601String().substring(0, 10);

    try {
      // 1) Existe-t-il déjà une évaluation ce jour pour cet agent ? (recalage)
      final existantes = await _supabase
          .from('evaluations')
          .select('id, score')
          .eq('agent_id', agentId)
          .eq('date_evaluation', iso);

      if (existantes.isNotEmpty) {
        double meilleureExistante = 0.0;
        for (final e in existantes) {
          final s = (e['score'] as num?)?.toDouble() ?? 0.0;
          if (s > meilleureExistante) meilleureExistante = s;
        }

        if (scoreTotal > meilleureExistante) {
          // La nouvelle note est meilleure : elle remplace les anciennes du jour.
          final idsASupprimer =
              existantes.map((e) => e['id'].toString()).toList();
          await _supabase.from('evaluations').delete().inFilter('id', idsASupprimer);
          await _supabase.from('evaluations').insert({
            'agent_id': agentId,
            'score': scoreTotal,
            'commentaire': commentaire ?? '',
            'items_evalues': items,
            'evaluateur': evaluateur ?? '',
            'vacation': vacation ?? '',
            'date_evaluation': iso,
          });
          return ResultatEnregistrementEvaluation.recalageNouvelleNoteConservee;
        }
        // La note existante était déjà meilleure ou égale : on ne fait rien.
        return ResultatEnregistrementEvaluation.recalageAncienneNoteConservee;
      }

      // 2) Nouveau jour pour cet agent : vérifier le quota mensuel.
      final maxJours = await getMaxJoursEvaluation();
      if (maxJours != null) {
        final joursEvalues =
            await compterJoursEvaluesDuMois(agentId, dateEvaluation);
        if (joursEvalues >= maxJours) {
          return ResultatEnregistrementEvaluation.quotaAtteintIgnore;
        }
      }

      // 3) Insertion normale.
      await _supabase.from('evaluations').insert({
        'agent_id': agentId,
        'score': scoreTotal,
        'commentaire': commentaire ?? '',
        'items_evalues': items,
        'evaluateur': evaluateur ?? '',
        'vacation': vacation ?? '',
        'date_evaluation': iso,
      });
      return ResultatEnregistrementEvaluation.insere;
    } catch (e) {
      throw Exception("Erreur d'enregistrement contrôlé de l'évaluation : $e");
    }
  }

  Future<bool> estDebloque({
    required String ville,
    required String service,
    required DateTime dateCible,
    String? vacation,
  }) async {
    try {
      final iso = dateCible.toIso8601String().substring(0, 10);
      final nowIso = DateTime.now().toIso8601String();
      final List<dynamic> response = await _supabase
          .from('deblocages_evaluation')
          .select('id, vacation, expire_le')
          .eq('ville', ville)
          .eq('service', service)
          .eq('date_cible', iso)
          .gt('expire_le', nowIso);

      if (response.isEmpty) return false;

      // Un déblocage sans vacation précisée couvre toute la journée.
      return response.any((d) {
        final v = d['vacation'];
        if (v == null || (v is String && v.isEmpty)) return true;
        return v == vacation;
      });
    } catch (e) {
      return false;
    }
  }

  /// Met à jour les informations d'un agent
  Future<void> updateEmployee(Map<String, dynamic> employee) async {
  try {
    await _supabase.from('agents').update({
      'nom': employee['nom'],
      'prenom': employee['prenom'],
      'fonction': employee['fonction'],
      'genre': employee['genre'],
      'ville': employee['ville'],
      'service': employee['service'],
      'date_embauche': employee['dateEmbauche'],
    }).eq('id', employee['id']);
    await init();
  } catch (e) {
    
    throw SupabaseUnavailableException(
        "Impossible de modifier l'agent.\nVérifiez votre connexion Internet.");
  }
}

  /// Supprime un agent (la suppression en cascade doit être activée sur Supabase pour les évaluations)
 Future<void> removeEmployee(String id) async {
  try {
    await _supabase.from('agents').delete().eq('id', id);
    employees.removeWhere((e) => e['id'] == id);
  } catch (e) {
    
    throw SupabaseUnavailableException(
        "Impossible de supprimer l'agent.\nVérifiez votre connexion Internet.");
  }
}
  
  Future<void> resetByServiceVille({
  required List<String> services,
  required String ville,
}) async {
  try {
    

    

    // Requête corrigée — un service à la fois si inFilter pose problème
    final List<dynamic> agentsASupprimer = [];
    
    for (final service in services) {
      final result = await _supabase
          .from('agents')
          .select('id')
          .eq('ville', ville)
          .eq('service', service);
      agentsASupprimer.addAll(result);
    }

    

    final ids = agentsASupprimer.map((a) => a['id']).toList();
    if (ids.isEmpty) {
     
      return;
    }

    // Supprimer les évaluations liées
    await _supabase
        .from('evaluations')
        .delete()
        .inFilter('agent_id', ids);
   

    // Supprimer les agents
    for (final service in services) {
      await _supabase
          .from('agents')
          .delete()
          .eq('ville', ville)
          .eq('service', service);
    }
    

    await init();
  } catch (e) {
    
    throw Exception("Erreur reset service : $e");
  }
}



}