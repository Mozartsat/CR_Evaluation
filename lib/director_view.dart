import 'package:flutter/material.dart';
import 'employee_repository.dart';
import 'evaluation_unlock_view.dart'; // ← déblocage évaluations (DEX)
import 'auth_manager.dart';
import 'login_screen.dart'; // ← LoginScreen, pour y revenir après déconnexion
import 'change_password_dialog.dart'; // ← Changer son propre mot de passe

class DirectorDashboardView extends StatefulWidget {
  final String targetCity;
  // Optionnel : quand renseigné (ouverture par un compte admin depuis
  // MainDashboard via Navigator.push), affiche une flèche retour dans la
  // sidebar qui ramène à MainDashboard SANS déconnecter le compte. Les
  // vrais comptes DEX (via login_screen.dart) n'utilisent pas ce paramètre
  // et gardent leur comportement inchangé (Déconnexion → LoginScreen).
  final VoidCallback? onBackToAdmin;

  const DirectorDashboardView({
    super.key,
    required this.targetCity,
    this.onBackToAdmin,
  });

  @override
  State<DirectorDashboardView> createState() => _DirectorDashboardViewState();
}

class _DirectorDashboardViewState extends State<DirectorDashboardView> {
  List<Map<String, dynamic>> _allAgents = [];
  bool _isLoading = true;
  String _selectedService = 'Tous';
  // Bascule vers l'écran de déblocage des évaluations (Rep/DEX/Admin)
  bool _showDeblocageEvaluations = false;
  // Mois sélectionné pour le "meilleur agent du mois" / top par service.
  // null tant que rien n'est encore chargé ; se cale ensuite sur le mois
  // le plus récent disponible (voir _buildMainContent). Une fois que le
  // directeur clique sur un chip (y compris "Tous"), _monthExplicitlySelected
  // passe à true et _selectedMonthKey reflète exactement son choix (null
  // == "Tous" == cumul de toutes les périodes).
  String? _selectedMonthKey;
  bool _monthExplicitlySelected = false;
  // Replié par défaut ; s'ouvre au clic sur l'entête.
  bool _agentsRisqueExpanded = false;

  // Quota mensuel de jours d'évaluation par agent, fixé par le Rep/DEX
  // (EmployeeRepository.setMaxJoursEvaluation). null = pas de limite définie.
  int? _maxJoursQuota;

  static const List<String> _kMonthNamesShort = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
    'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _chargerQuota();
  }

  Future<void> _chargerQuota() async {
    try {
      final q = await EmployeeRepository.instance.getMaxJoursEvaluation();
      if (mounted) setState(() => _maxJoursQuota = q);
    } catch (_) {
      // Silencieux : le badge "jours évalués" reste simplement sans quota.
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await EmployeeRepository.instance.init();
    if (!mounted) return;

    final all = EmployeeRepository.instance.employees
        .where((e) => e['ville'] == widget.targetCity)
        .toList();

    if (!mounted) return;
    setState(() {
      _allAgents = all;
      _isLoading = false;
    });
  }

  double _calculateScore(Map<String, dynamic> emp) {
  final evals = emp['evaluations'] as List? ?? [];
  if (evals.isEmpty) return 0.0;
  
  // Somme brute de tous les points obtenus
  return evals.fold(0.0, (sum, e) {
    final val = double.tryParse(e['score']?.toString() ?? '0') ?? 0.0;
    return sum + val;
  });
}

  /// Regroupe les évaluations d'un agent par mois (clé "AAAA-MM") et
  /// additionne les notes de chaque mois.
  Map<String, double> _scoresByMonth(Map<String, dynamic> agent) {
    final evals = agent['evaluations'] as List? ?? [];
    final Map<String, double> totals = {};
    for (final e in evals) {
      final rawDate = e['created_at']?.toString() ?? '';
      if (rawDate.isEmpty) continue;
      final date = DateTime.tryParse(rawDate);
      if (date == null) continue;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final score = double.tryParse(e['score']?.toString() ?? '0') ?? 0.0;
      totals[key] = (totals[key] ?? 0) + score;
    }
    return totals;
  }

  /// Score d'un agent pour un mois donné ("AAAA-MM"), ou son total cumulé
  /// si monthKey est null.
  double _scoreForMonth(Map<String, dynamic> agent, String? monthKey) {
    if (monthKey == null) return _calculateScore(agent);
    return _scoresByMonth(agent)[monthKey] ?? 0.0;
  }

  /// Dates distinctes (date_evaluation) d'un agent pour la période donnée :
  /// un mois précis ("AAAA-MM"), ou le cumul complet si monthKey est null.
  /// Même principe que côté ScoreView (reps), pour rester cohérent avec le
  /// quota mensuel fixé par le Rep/DEX.
  Set<String> _distinctEvalDatesForPeriod(Map<String, dynamic> agent, String? monthKey) {
    final evals = agent['evaluations'] as List? ?? [];
    final dates = <String>{};
    for (final e in evals) {
      final rawDate = (e['date_evaluation'] ?? '').toString();
      if (rawDate.isEmpty) continue;
      if (monthKey == null) {
        dates.add(rawDate);
        continue;
      }
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      final key = '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}';
      if (key == monthKey) dates.add(rawDate);
    }
    return dates;
  }

  /// Libellé "jours évalués" pour un agent sur la période donnée, ex :
  /// "10/22 j." (mois précis, quota connu) ou "24 j. (cumul)" en vue "Tous".
  String? _joursLabelForPeriod(Map<String, dynamic> agent, String? monthKey) {
    final dates = _distinctEvalDatesForPeriod(agent, monthKey);
    if (monthKey == null) {
      if (dates.isEmpty) return null;
      return "${dates.length} j. (cumul)";
    }
    if (dates.isEmpty && _maxJoursQuota == null) return null;
    if (_maxJoursQuota == null) return "${dates.length} j. évalués";
    return "${dates.length}/$_maxJoursQuota j.";
  }

  /// Petite pastille cyan pour l'info "jours évalués / quota" — couleur
  /// volontairement distincte de l'ambre (meilleur agent/points) et du
  /// rouge/orange (retards), pour rester immédiatement repérable dans le
  /// classement du directeur comme dans celui des reps.
  Widget _buildJoursBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Toutes les clés de mois ("AAAA-MM") présentes dans les évaluations,
  /// triées du plus récent au plus ancien.
  List<String> _allMonthKeysDesc() {
    final Set<String> keys = {};
    for (final agent in _allAgents) {
      keys.addAll(_scoresByMonth(agent).keys);
    }
    final list = keys.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  /// Meilleur agent de chaque service pour le mois donné (null = total
  /// cumulé). Un agent sans évaluation ce mois-là n'est pas candidat.
  List<Map<String, dynamic>> _topAgentsByServiceForMonth(String? monthKey) {
    const services = ['Passage', 'Ops', 'Piste', 'Fret', 'Garage'];
    final List<Map<String, dynamic>> toppers = [];
    for (final srv in services) {
      var srvAgents = _allAgents.where((e) => e['service'] == srv).toList();
      if (monthKey != null) {
        srvAgents = srvAgents.where((a) => _scoreForMonth(a, monthKey) > 0).toList();
      }
      if (srvAgents.isNotEmpty) {
        srvAgents.sort((a, b) => _scoreForMonth(b, monthKey).compareTo(_scoreForMonth(a, monthKey)));
        toppers.add(srvAgents.first);
      }
    }
    return toppers;
  }

  /// Libellés de choix "Ponctualité" comptabilisés comme un retard.
  static const Set<String> _kChoixRetard = {
    'h+7 à 15mn',
    'au dela de 15mn',
    'au delà de 15mn',
    'au-delà de 15mn',
  };

  /// True si l'évaluation contient un item "Ponctualité" dont le choix
  /// correspond à un des libellés de retard (_kChoixRetard).
  bool _evalHasRetard(Map<String, dynamic> eval) {
    final items = eval['items_evalues'] as List? ?? [];
    final item = items.firstWhere(
      (it) => it['critere']?.toString().toLowerCase() == 'ponctualité',
      orElse: () => null,
    );
    if (item == null) return false;
    final choix = item['choix']?.toString().trim().toLowerCase() ?? '';
    return _kChoixRetard.contains(choix);
  }

  /// Statistiques de ponctualité d'un agent, calculées à partir de tous
  /// ses items "Ponctualité" évalués. Un choix est compté comme retard
  /// s'il correspond (insensible à la casse) à un des libellés de
  /// `_kChoixRetard` ; tout autre choix ("À l'heure", etc.) est ponctuel.
  Map<String, dynamic> _ponctualiteStats(Map<String, dynamic> agent) {
    final evals = agent['evaluations'] as List? ?? [];
    int totalPonctualite = 0;
    int totalRetards = 0;
    final Map<String, int> retardsParTranche = {};

    for (final e in evals) {
      final items = e['items_evalues'] as List? ?? [];
      final item = items.firstWhere(
        (it) => it['critere']?.toString().toLowerCase() == 'ponctualité',
        orElse: () => null,
      );
      if (item == null) continue;
      totalPonctualite++;
      final choix = item['choix']?.toString().trim() ?? '';
      if (_kChoixRetard.contains(choix.toLowerCase())) {
        totalRetards++;
        retardsParTranche[choix] = (retardsParTranche[choix] ?? 0) + 1;
      }
    }

    final tauxRetard =
        totalPonctualite == 0 ? 0.0 : (totalRetards / totalPonctualite) * 100;

    return {
      'totalPonctualite': totalPonctualite,
      'totalRetards': totalRetards,
      'tauxRetard': tauxRetard,
      'retardsParTranche': retardsParTranche,
    };
  }

  /// Taux de retard global, tous agents confondus (pour le KPI directeur).
  Map<String, dynamic> _ponctualiteStatsGlobal() {
    int totalPonctualite = 0;
    int totalRetards = 0;
    for (final agent in _allAgents) {
      final s = _ponctualiteStats(agent);
      totalPonctualite += s['totalPonctualite'] as int;
      totalRetards += s['totalRetards'] as int;
    }
    final taux =
        totalPonctualite == 0 ? 0.0 : (totalRetards / totalPonctualite) * 100;
    return {
      'totalPonctualite': totalPonctualite,
      'totalRetards': totalRetards,
      'tauxRetard': taux,
    };
  }

  /// Un agent est considéré "en risque" si LES DEUX conditions sont réunies :
  /// - son taux de retard (Ponctualité) est > 20%, ET
  /// - son score mensuel décroît sur 2 mois consécutifs
  ///   (ex: Jan 60 → Fév 55 → Mar 50).
  bool _isAgentAtRisk(Map<String, dynamic> agent) {
    final retard = _ponctualiteStats(agent);
    final tauxRetard = retard['tauxRetard'] as double;
    if (tauxRetard <= 20) return false;

    final monthly = _scoresByMonth(agent);
    final keys = monthly.keys.toList()..sort();
    if (keys.length < 3) return false;

    final last3 = keys.sublist(keys.length - 3);
    final m1 = monthly[last3[0]] ?? 0;
    final m2 = monthly[last3[1]] ?? 0;
    final m3 = monthly[last3[2]] ?? 0;

    return m1 > m2 && m2 > m3;
  }

  List<Map<String, dynamic>> _agentsAtRisk() {
    return _allAgents.where(_isAgentAtRisk).toList();
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    return "${_kMonthNamesShort[month - 1]} ${year.substring(2)}";
  }

  // --- FICHE DÉTAILLÉE AVEC NOTES PAR MOIS + RÉCAPITULATIF DES ITEMS ---
 void _showAgentDetails(Map<String, dynamic> agent) {
  final List evals = agent['evaluations'] as List? ?? [];
  final monthTotals = _scoresByMonth(agent);
  final sortedMonthKeys = monthTotals.keys.toList()..sort((a, b) => b.compareTo(a));
  String? selectedMonthKey; // null = toutes les évaluations, tous mois confondus

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final displayedEvals = selectedMonthKey == null
            ? evals
            : evals.where((e) {
                final rawDate = e['created_at']?.toString() ?? '';
                final date = DateTime.tryParse(rawDate);
                if (date == null) return false;
                final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
                return key == selectedMonthKey;
              }).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF0F1021),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 25),
              _buildAgentHeader(agent),
              const SizedBox(height: 25),

              // SECTION : NOTES PAR MOIS (nouveau)
              if (sortedMonthKeys.isNotEmpty) ...[
                const Text("NOTES PAR MOIS", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 58,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildMonthChip(
                        label: "Tout",
                        score: null,
                        isSelected: selectedMonthKey == null,
                        onTap: () => setModalState(() => selectedMonthKey = null),
                      ),
                      ...sortedMonthKeys.map((key) => _buildMonthChip(
                            label: _monthLabel(key),
                            score: monthTotals[key],
                            isSelected: selectedMonthKey == key,
                            onTap: () => setModalState(() => selectedMonthKey = key),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],
          
          // SECTION : DÉCORTICAGE DES ITEMS
          Text(
            selectedMonthKey == null
                ? "DÉTAILS DES ITEMS ÉVALUÉS"
                : "DÉTAILS — ${_monthLabel(selectedMonthKey!)}",
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: displayedEvals.isEmpty 
              ? const Center(child: Text("Aucun item sélectionné", style: TextStyle(color: Colors.white24)))
              : ListView.builder(
                  itemCount: displayedEvals.length,
                  itemBuilder: (context, index) => _buildInspectionListTile(displayedEvals[index]),
                ),
          ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _buildMonthChip({
  required String label,
  double? score,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.amber : Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.amber : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (score != null)
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  color: isSelected ? Colors.amber : Colors.white38,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildAgentHeader(Map<String, dynamic> agent) {
  final String nom = agent['nom']?.toString() ?? "Nom";
  final String prenom = agent['prenom']?.toString() ?? "Inconnu";
  final double totalScore = _calculateScore(agent);
  final String? joursLabel = _joursLabelForPeriod(agent, null);

  return Row(
    children: [
      CircleAvatar(
        radius: 35,
        backgroundColor: Colors.amber.withOpacity(0.1),
        child: Text(
          nom.isNotEmpty ? nom[0].toUpperCase() : "?",
          style: const TextStyle(fontSize: 28, color: Colors.amber, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(width: 20),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$nom $prenom", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(
              "${agent['service'] ?? 'Service'} • ${agent['fonction'] ?? 'Agent'}",
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text("$totalScore", style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold)),
          const Text("POINTS TOTAL", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (joursLabel != null) ...[
            _buildJoursBadge(joursLabel),
            const SizedBox(height: 8),
          ],
          _buildRetardBadge(_ponctualiteStats(agent)),
        ],
      ),
    ],
  );
}

Widget _buildInspectionListTile(Map<String, dynamic> eval) {
  final double scoreGlobal = double.tryParse(eval['score']?.toString() ?? '0') ?? 0.0;
  final bool hasRetard = _evalHasRetard(eval);
  final Color accent = hasRetard ? Colors.redAccent : Colors.amber;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: hasRetard ? Colors.redAccent.withOpacity(0.08) : const Color(0xFF16112F),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: hasRetard ? Colors.redAccent.withOpacity(0.4) : Colors.white.withOpacity(0.05)),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showEvaluationDetailsDialog(eval),
        child: ListTile(
          leading: Icon(hasRetard ? Icons.schedule_outlined : Icons.assignment_outlined, color: accent, size: 20),
          title: Text(
            hasRetard ? "Détails de l'évaluation — retard signalé" : "Détails de l'évaluation",
            style: TextStyle(color: hasRetard ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          trailing: Text("$scoreGlobal",
              style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    ),
  );
}

/// Popup (fermable) avec le détail complet d'une évaluation :
/// vacation, évaluateur, puis chaque critère avec sa note.
void _showEvaluationDetailsDialog(Map<String, dynamic> eval) {
  final List itemsDetails = eval['items_evalues'] as List? ?? [];
  final double scoreGlobal = double.tryParse(eval['score']?.toString() ?? '0') ?? 0.0;
  final String vacation = (eval['vacation'] as String?) ?? '';
  final String evaluateur = (eval['evaluateur'] as String?) ?? '';

  const criteres = [
    'Ponctualité',
    'Tenue de travail',
    'Comportement',
    'Maîtrise de poste',
    "Esprit d'initiative",
  ];

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF16112F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.assignment_outlined, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text("Détails de l'évaluation",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Text("$scoreGlobal",
              style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VACATION + ÉVALUATEUR
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoBlock(Icons.schedule, "Vacation", vacation.isEmpty ? '—' : vacation),
                  ),
                  Container(width: 1, height: 30, color: Colors.white10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoBlock(Icons.person_outline, "Évaluateur", evaluateur.isEmpty ? '—' : evaluateur),
                  ),
                ],
              ),
            ),
            // CRITÈRES + NOTES
            ...criteres.map((c) => _buildDetailRow(c, itemsDetails)),
          ],
        ),
      ),
      actions: [
        Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: const Text("Fermer"),
          ),
        ),
      ],
    ),
  );
}

Widget _buildInfoBlock(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 14, color: Colors.white38),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildDetailRow(String categorie, List items) {
  // On cherche l'item qui correspond au critère (ex: Ponctualité).
  // Les items enregistrés utilisent les clés 'critere' / 'choix' / 'score'.
  final item = items.firstWhere(
    (e) => e['critere']?.toString().toLowerCase() == categorie.toLowerCase(),
    orElse: () => null,
  );
  final scoreValue = item?['score'];
  final scoreText = scoreValue == null
      ? "-"
      : (double.tryParse(scoreValue.toString())?.toStringAsFixed(1) ?? "-");

  final String choixText = item?['choix']?.toString() ?? "Non évalué";
  final bool isRetard = categorie.toLowerCase() == 'ponctualité' &&
      _kChoixRetard.contains(choixText.trim().toLowerCase());

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(categorie, 
                style: TextStyle(color: isRetard ? Colors.redAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              // Affiche le choix retenu (ex: "H+7 à 15mn")
              Row(
                children: [
                  if (isRetard) ...[
                    const Icon(Icons.schedule_outlined, size: 12, color: Colors.redAccent),
                    const SizedBox(width: 4),
                  ],
                  Text(choixText, 
                    style: TextStyle(color: isRetard ? Colors.redAccent : Colors.white38, fontSize: 11, fontWeight: isRetard ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            ],
          ),
        ),
        // Affiche la note associée à ce critère précis
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isRetard ? Colors.redAccent.withOpacity(0.12) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            scoreText, 
            style: TextStyle(color: isRetard ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

  
  

  // --- RESTE DE L'INTERFACE (DESIGN SIDEPAR & MAIN) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A051D),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _showDeblocageEvaluations
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Déblocage évaluations",
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Rechercher et débloquer une évaluation bloquée depuis plus de 48h",
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: EvaluationUnlockView(
                                ville: widget.targetCity,
                                allowServicePicker: true,
                                debloquePar: "DEX ${widget.targetCity}",
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF0F0A25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(children: [
              if (widget.onBackToAdmin != null) ...[
                IconButton(
                  onPressed: widget.onBackToAdmin,
                  icon: const Icon(Icons.arrow_back, color: Colors.white54, size: 18),
                  tooltip: "Retour à l'espace admin",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.diamond, color: Colors.amber), const SizedBox(width: 10), Text("DIR. ${widget.targetCity}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
          ),
          _buildNavTile("Tableau de bord", Icons.dashboard, () => setState(() {
            _selectedService = 'Tous';
            _showDeblocageEvaluations = false;
          }), active: _selectedService == 'Tous' && !_showDeblocageEvaluations),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 15), child: Text("SERVICES", style: TextStyle(color: Colors.white24, fontSize: 11))),
          ...['Passage', 'Ops', 'Piste', 'Fret', 'Garage'].map((s) => _buildServiceTile(s)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 15), child: Text("ADMINISTRATION", style: TextStyle(color: Colors.white24, fontSize: 11))),
          _buildNavTile(
            "Déblocage évaluations",
            Icons.lock_open_outlined,
            () => setState(() => _showDeblocageEvaluations = true),
            active: _showDeblocageEvaluations,
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Colors.white12, height: 1),
          ),
          const SizedBox(height: 8),
          _buildNavTile("Changer mon mot de passe", Icons.key_outlined, () => showChangePasswordDialog(context)),
          _buildNavTile("Déconnexion", Icons.logout, _confirmLogout, color: Colors.redAccent),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Demande confirmation puis déconnecte l'utilisateur via AuthManager,
  /// puis ramène au premier écran de la pile de navigation (login).
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16112F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Déconnexion", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "Voulez-vous vraiment vous déconnecter ?",
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx); // ferme la boîte de dialogue
              AuthManager.logout();
              // DirectorDashboardView est arrivé ici via pushReplacement
              // depuis LoginScreen (voir main.dart), donc LoginScreen
              // n'existe plus dans la pile — on y retourne explicitement.
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Se déconnecter"),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final monthKeys = _allMonthKeysDesc();
    // Se cale sur le mois le plus récent disponible tant que le directeur
    // n'a rien choisi explicitement (y compris "Tous", qui correspond à
    // _selectedMonthKey == null une fois choisi explicitement).
    final String? effectiveMonthKey = _monthExplicitlySelected
        ? _selectedMonthKey
        : (monthKeys.isNotEmpty ? monthKeys.first : null);

    final topAgentsByService = _topAgentsByServiceForMonth(effectiveMonthKey);

    // Le "meilleur agent du mois" est le véritable meilleur score, pour le
    // mois sélectionné (ou le cumul si "Tous"), parmi les tops de chaque
    // service.
    final Map<String, dynamic>? topAgent = topAgentsByService.isEmpty
        ? null
        : topAgentsByService.reduce(
            (a, b) => _scoreForMonth(a, effectiveMonthKey) >= _scoreForMonth(b, effectiveMonthKey) ? a : b,
          );

    final displayList = _selectedService == 'Tous'
        // On retire le service du meilleur agent : il est déjà mis en
        // avant dans le cadre "Meilleur agent du mois", pas besoin de le
        // re-lister comme simple nominé de son service.
        ? topAgentsByService
            .where((a) => topAgent == null || a['service'] != topAgent['service'])
            .toList()
        // Vue équipe : même principe — classement et notes basés sur le
        // mois sélectionné (ou le cumul si "Tous").
        : (_allAgents.where((e) => e['service'] == _selectedService).toList()
            ..sort((a, b) => _scoreForMonth(b, effectiveMonthKey).compareTo(_scoreForMonth(a, effectiveMonthKey))));

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_agentsRisqueExpanded) setState(() => _agentsRisqueExpanded = false);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière directeur — même principe que _buildHomePage() dans
            // main.dart (Image.asset locale, avec fallback si le fichier
            // n'est pas trouvé).
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/director.jpg',
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // TEMPORAIRE : à retirer une fois le diagnostic fait.
                  debugPrint("❌ Échec chargement assets/images/director.png : $error");
                  return Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16112F),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 32),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text("Bonjour, Directeur", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const Text("Analyse des performances mensuelles", style: TextStyle(color: Colors.white38)),
            const SizedBox(height: 28),
            _buildKpiRow(),
            const SizedBox(height: 40),
            if (monthKeys.isNotEmpty) ...[
              _buildMonthSelector(monthKeys, effectiveMonthKey),
              const SizedBox(height: 20),
            ],
            if (_selectedService == 'Tous' && topAgent != null) _buildHallOfFameSection(topAgent, effectiveMonthKey),
            const SizedBox(height: 40),
            if (_selectedService == 'Tous') ...[
              _buildAgentsRisqueSection(),
              const SizedBox(height: 40),
            ],
            Text(_selectedService == 'Tous' ? "NOMINÉS PAR SERVICE" : "ÉQUIPE : $_selectedService", 
                 style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: displayList
                      .map((agent) => SizedBox(width: itemWidth, child: _buildNomineeCard(agent, effectiveMonthKey)))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Rangée de chips permettant au directeur de choisir le mois (ou "Tous"
  /// pour le cumul de toutes les périodes) pour lequel afficher le
  /// "meilleur agent du mois" / top par service / notes des nominés.
  Widget _buildMonthSelector(List<String> monthKeys, String? effectiveMonthKey) {
    final bool isAllSelected = _monthExplicitlySelected && _selectedMonthKey == null;

    Widget chip({required String label, required bool isSelected, required VoidCallback onTap}) {
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onTap(),
          backgroundColor: const Color(0xFF16112F),
          selectedColor: Colors.amber.withOpacity(0.18),
          labelStyle: TextStyle(
            color: isSelected ? Colors.amber : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? Colors.amber : Colors.white12),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(
            label: "Tous",
            isSelected: isAllSelected,
            onTap: () => setState(() {
              _selectedMonthKey = null;
              _monthExplicitlySelected = true;
            }),
          ),
          ...monthKeys.map((key) {
            final bool isSelected = !isAllSelected && key == effectiveMonthKey;
            return chip(
              label: _monthLabel(key),
              isSelected: isSelected,
              onTap: () => setState(() {
                _selectedMonthKey = key;
                _monthExplicitlySelected = true;
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    final totalAgents = _allAgents.length;
    int evalsThisMonth = 0;
    final now = DateTime.now();
    final Set<String> services = {};

    for (final agent in _allAgents) {
      final svc = agent['service']?.toString();
      if (svc != null && svc.isNotEmpty) services.add(svc);

      final evals = agent['evaluations'] as List? ?? [];
      for (final e in evals) {
        final rawDate = e['created_at']?.toString() ?? '';
        final date = DateTime.tryParse(rawDate);
        if (date != null && date.year == now.year && date.month == now.month) {
          evalsThisMonth++;
        }
      }
    }

    final retardGlobal = _ponctualiteStatsGlobal();
    final tauxRetard = retardGlobal['tauxRetard'] as double;
    final nbAgentsRisque = _agentsAtRisk().length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 5 cartes : on garde une seule ligne sur grand écran, et on
        // bascule automatiquement sur 2 lignes si l'espace manque.
        final cardWidth = (constraints.maxWidth - 14 * 4) / 5;
        final useWrap = cardWidth < 140;

        final cards = [
          _kpiCard("Agents actifs", "$totalAgents", Icons.groups_outlined),
          _kpiCard("Évaluations ce mois", "$evalsThisMonth", Icons.fact_check_outlined),
          _kpiCard("Services couverts", "${services.length}", Icons.apartment_outlined),
          _kpiCard(
            "Taux de retard",
            "${tauxRetard.toStringAsFixed(1)}%",
            Icons.schedule_outlined,
            accentColor: tauxRetard >= 20
                ? Colors.redAccent
                : (tauxRetard >= 10 ? Colors.orangeAccent : Colors.greenAccent),
            tooltip: "Part des évaluations de ponctualité marquées "
                "\"H+7 à 15mn\" ou \"Au-delà de 15mn\" parmi toutes les "
                "évaluations de ponctualité enregistrées, tous agents "
                "confondus.",
          ),
          _kpiCard(
            "Agents en risque",
            "$nbAgentsRisque",
            Icons.warning_amber_outlined,
            accentColor: nbAgentsRisque > 0 ? Colors.redAccent : Colors.greenAccent,
            tooltip: "Agent en risque = taux de retard individuel > 20% "
                "ET score en baisse sur 2 mois consécutifs "
                "(ex: Jan 60 → Fév 55 → Mar 50). Les deux conditions "
                "doivent être réunies.",
          ),
        ];

        if (!useWrap) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards.map((c) => SizedBox(width: 160, child: c)).toList(),
        );
      },
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, {Color? accentColor, String? tooltip}) {
    final color = accentColor ?? Colors.purpleAccent;
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16112F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              if (tooltip != null) ...[
                const Spacer(),
                Tooltip(
                  message: tooltip,
                  triggerMode: TooltipTriggerMode.tap,
                  textStyle: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF221A45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(Icons.info_outline, color: Colors.white38, size: 14),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color == Colors.purpleAccent ? Colors.white : color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
    return card;
  }

  Widget _buildHallOfFameSection(Map<String, dynamic> top, String? monthKey) {
    final retard = _ponctualiteStats(top);
    final double score = _scoreForMonth(top, monthKey);
    final String? joursLabel = _joursLabelForPeriod(top, monthKey);
    final String periodLabel = monthKey == null ? "TOUTE PÉRIODE" : _monthLabel(monthKey).toUpperCase();
    return InkWell(
      onTap: () => _showAgentDetails(top),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.amber.withOpacity(0.15), Colors.transparent]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 50),
            const SizedBox(width: 25),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${top['nom']} ${top['prenom']}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text("MEILLEUR AGENT — $periodLabel · CLIQUEZ POUR LES DÉTAILS", style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Service : ${top['service'] ?? '—'}", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRetardBadge(retard),
                      if (joursLabel != null) ...[
                        const SizedBox(width: 8),
                        _buildJoursBadge(joursLabel),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(score.toStringAsFixed(1), style: const TextStyle(color: Colors.amber, fontSize: 36, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Section listant les agents en risque (retards fréquents et/ou score
  /// en baisse). N'affiche rien si aucun agent n'est concerné. Repliée par
  /// défaut : un clic sur l'entête l'ouvre/la ferme, un clic ailleurs sur
  /// la page la referme si elle était ouverte.
  Widget _buildAgentsRisqueSection() {
    final agents = _agentsAtRisk();
    if (agents.isEmpty) return const SizedBox.shrink();

    return TapRegion(
      onTapOutside: (_) {
        if (_agentsRisqueExpanded) setState(() => _agentsRisqueExpanded = false);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _agentsRisqueExpanded = !_agentsRisqueExpanded),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("AGENTS EN RISQUE (${agents.length})",
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  Icon(
                    _agentsRisqueExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
            if (_agentsRisqueExpanded) ...[
              const SizedBox(height: 4),
              const Text(
                "Taux de retard > 20% et score en baisse sur 2 mois consécutifs",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 14),
              ...agents.map((agent) => _buildAgentRisqueTile(agent)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAgentRisqueTile(Map<String, dynamic> agent) {
    final retard = _ponctualiteStats(agent);
    final monthly = _scoresByMonth(agent);
    final keys = monthly.keys.toList()..sort();
    String tendance = '';
    if (keys.length >= 3) {
      final last3 = keys.sublist(keys.length - 3);
      final points = last3
          .map((k) => "${_monthLabel(k)} ${(monthly[k] ?? 0).toStringAsFixed(1)}")
          .join(" → ");
      tendance = points;
    }

    return InkWell(
      onTap: () => _showAgentDetails(agent),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF16112F),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${agent['nom'] ?? ''} ${agent['prenom'] ?? ''}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("${agent['service'] ?? 'Non assigné'}",
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  if (tendance.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_down, size: 12, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text(tendance, style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _buildRetardBadge(retard),
          ],
        ),
      ),
    );
  }

  /// Petit badge "X retards / Y évaluations (Z%)" utilisé sur les cartes
  /// agent et dans la fiche détaillée.
  Widget _buildRetardBadge(Map<String, dynamic> retard) {
    final int total = retard['totalPonctualite'] as int;
    final int nb = retard['totalRetards'] as int;
    final double taux = retard['tauxRetard'] as double;
    if (total == 0) {
      return const SizedBox.shrink();
    }
    final Color color = taux >= 20
        ? Colors.redAccent
        : (taux >= 10 ? Colors.orangeAccent : Colors.greenAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            "$nb retard${nb > 1 ? 's' : ''} / $total (${taux.toStringAsFixed(0)}%)",
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNomineeCard(Map<String, dynamic> agent, String? monthKey) {
  final retard = _ponctualiteStats(agent);
  final double score = _scoreForMonth(agent, monthKey);
  final bool hasScore = score > 0;
  final String? joursLabel = _joursLabelForPeriod(agent, monthKey);
  return InkWell(
      onTap: () => _showAgentDetails(agent),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF16112F), 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: hasScore ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.06))
        ),
        child: Opacity(
          opacity: hasScore ? 1.0 : 0.55,
          child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white10, 
              child: Text(
                (agent['nom'] != null && agent['nom'].toString().isNotEmpty) 
                  ? agent['nom'][0].toUpperCase() 
                  : "?",
                // CORRECTION ICI : Un seul argument style avec toutes les propriétés
                style: const TextStyle(color: Colors.white, fontSize: 14), 
              )
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sécurisation contre le Null pour le nom complet
                  Text(
                    "${agent['nom'] ?? ''} ${agent['prenom'] ?? ''}", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Sécurisation contre le Null pour le service
                  Text(
                    "${agent['service'] ?? 'Non assigné'}", 
                    style: const TextStyle(color: Colors.white38, fontSize: 12)
                  ),
                  if (!hasScore) ...[
                    const SizedBox(height: 6),
                    _buildNoScoreBadge(),
                  ] else if ((retard['totalPonctualite'] as int) > 0) ...[
                    const SizedBox(height: 6),
                    _buildRetardBadge(retard),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white10),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasScore ? score.toStringAsFixed(1) : "—", 
                  style: TextStyle(color: hasScore ? Colors.blueAccent : Colors.white38, fontSize: 18, fontWeight: FontWeight.bold)
                ),
                if (joursLabel != null) ...[
                  const SizedBox(height: 4),
                  _buildJoursBadge(joursLabel),
                ],
              ],
            ),
          ],
          ),
        ),
      ),
  );
}

  /// Badge gris "Pas de note" pour signaler visuellement un agent sans
  /// évaluation notée sur la période sélectionnée (0 point), à distinguer
  /// d'un agent qui a réellement une note > 0.
  Widget _buildNoScoreBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.remove_circle_outline, size: 12, color: Colors.white38),
          SizedBox(width: 4),
          Text("Pas de note", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildServiceTile(String label) {
    bool isActive = _selectedService == label && !_showDeblocageEvaluations;
    return ListTile(
      onTap: () => setState(() {
        _selectedService = label;
        _showDeblocageEvaluations = false;
      }),
      leading: Icon(Icons.folder_open, color: isActive ? Colors.amber : Colors.white24, size: 20),
      title: Text(label, style: TextStyle(color: isActive ? Colors.amber : Colors.white70, fontSize: 14)),
      selected: isActive,
    );
  }

  Widget _buildNavTile(String label, IconData icon, VoidCallback onTap, {bool active = false, Color? color}) {
    final Color resolvedColor = color ?? (active ? Colors.amber : Colors.white);
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? (active ? Colors.amber : Colors.white54)),
      title: Text(label, style: TextStyle(color: resolvedColor, fontSize: 14)),
    );
  }
}