import 'package:flutter/material.dart';

// --- DONNÉES DES CRITÈRES (Inchangées) ---
const List<Map<String, dynamic>> _kCriteria = [
  {
    'title': 'Ponctualité',
    'emoji': '⏰',
    'options': [
      {'text': 'H+7 à 15mn', 'emoji': '😴', 'score': 0.0},
      {'text': 'retardataire briefing', 'emoji': '😴', 'score': 0.0},
      {'text': 'absent briefing', 'emoji': '😴', 'score': 0.0},
      {'text': 'MEP non respectée', 'emoji': '😴', 'score': 0.0},
      {'text': 'H-1 à 6mn', 'emoji': '😐', 'score': 1.5},
      {'text': 'H-2 à 15mn', 'emoji': '😊', 'score': 2.5},
      {'text': 'H-15 à -30mn', 'emoji': '😃', 'score': 3.0},
    ],
  },
  {
    'title': 'Tenue de travail',
    'emoji': '👔',
    'options': [
      {'text': 'Sale', 'emoji': '😖', 'score': 0.0},
      {'text': 'Mal propre', 'emoji': '😕', 'score': 1.0},
      {'text': 'code vestimentaire non respecté', 'emoji': '😕', 'score': 1.0},
      {'text': 'non port cravate', 'emoji': '😐', 'score': 2.0},
      {'text': 'non port foulard', 'emoji': '😐', 'score': 2.0},
      {'text': 'Propre', 'emoji': '😊', 'score': 3.0},
      {'text': 'Très propre', 'emoji': '😃', 'score': 3.5},
    ],
  },
  {
    'title': 'Comportement',
    'emoji': '😊',
    'options': [
      {'text': 'Indiscipliné', 'emoji': '😠', 'score': 0.0},
      {'text': 'accro téléphone', 'emoji': '📱😠', 'score': 0.0},
      {'text': 'nerveux', 'emoji': '😤', 'score': 0.0},
      {'text': 'désertion poste', 'emoji': '😠', 'score': 0.0},
      {'text': 'Répartition non respectée', 'emoji': '😕', 'score': 0.5},
      {'text': 'Boudeur', 'emoji': '😒', 'score': 0.5},
      {'text': 'Poli', 'emoji': '😊', 'score': 2.0},
      {'text': 'respectueux', 'emoji': '😊', 'score': 2.0},
      {'text': 'Dynamique', 'emoji': '😄', 'score': 3.5},
      {'text': 'Motivé', 'emoji': '😄', 'score': 3.5},
      {'text': 'Déterminé', 'emoji': '😄', 'score': 3.5},
      {'text': 'très regardant', 'emoji': '😄', 'score': 3.5},
      {'text': 'Irreprochable', 'emoji': '😇', 'score': 4.5},
    ],
  },
  {
    'title': 'Maîtrise de poste',
    'emoji': '📋',
    'options': [
      {'text': 'Dossier mal fait', 'emoji': '😞', 'score': 0.5},
      {'text': 'vol non finalisé', 'emoji': '😞', 'score': 0.5},
      {'text': 'non respect consignes', 'emoji': '😞', 'score': 0.5},
      {'text': 'non respect procédures', 'emoji': '😞', 'score': 0.5},
      {'text': 'très lent', 'emoji': '😞', 'score': 0.5},
      {'text': 'non maîtrise DCS', 'emoji': '😕', 'score': 1.0},
      {'text': 'Méthodique', 'emoji': '😐', 'score': 1.0},
      {'text': 'respect consignes', 'emoji': '😊', 'score': 3.0},
      {'text': 'respect procédures', 'emoji': '😊', 'score': 3.0},
      {'text': 'maîtrise DCS', 'emoji': '😊', 'score': 3.0},
      {'text': 'Maîtrise procédures', 'emoji': '😊', 'score': 3.0},
      {'text': 'Dur à la tâche', 'emoji': '😄', 'score': 3.5},
      {'text': 'Compétent', 'emoji': '😃', 'score': 4.5},
      {'text': 'Excellent', 'emoji': '😍', 'score': 4.5},
    ],
  },
  {
    'title': 'Esprit d\'initiative',
    'emoji': '💡',
    'options': [
      {'text': 'Vol mal préparé', 'emoji': '😞', 'score': 0.0},
      {'text': 'Agent décevant', 'emoji': '😞', 'score': 0.0},
      {'text': 'Rêveur', 'emoji': '😴', 'score': 0.5},
      {'text': 'Aucune initiative', 'emoji': '😐', 'score': 1.0},
      {'text': 'Aucune implication', 'emoji': '😐', 'score': 1.0},
      {'text': 'vol bien préparé', 'emoji': '😊', 'score': 2.5},
      {'text': 'bonne anticipation', 'emoji': '😊', 'score': 2.5},
      {'text': 'Prise d\'initiatives', 'emoji': '😄', 'score': 3.5},
      {'text': 'Impliqué', 'emoji': '😄', 'score': 3.5},
      {'text': 'Proactif', 'emoji': '😄', 'score': 3.5},
      {'text': 'Très impliqué', 'emoji': '😃', 'score': 4.5},
      {'text': 'Bcp de propositions', 'emoji': '😃', 'score': 4.5},
      {'text': 'Excellente anticipation', 'emoji': '😍', 'score': 4.5},
    ],
  },
];

enum RankBadge { none, nominated, best }

// --- WIDGET CARTE AVEC ANIMATION RESSORT (CORRIGÉ) ---
class _AnimatedRankingCard extends StatefulWidget {
  final int rank;
  final Map<String, dynamic> emp;
  // Score affiché sur la carte = score de la PÉRIODE SÉLECTIONNÉE (mois ou
  // "Tous"), même base que le badge, pour éviter tout décalage entre ce qui
  // est affiché et ce qui détermine le badge.
  final double displayScore;
  final VoidCallback onTap;
  final RankBadge badge;
  // "du mois" ou "toutes périodes" selon le sélecteur.
  final String periodLabel;

  const _AnimatedRankingCard({
    required this.rank,
    required this.emp,
    required this.displayScore,
    required this.onTap,
    required this.badge,
    this.periodLabel = "du mois",
  });

  @override
  State<_AnimatedRankingCard> createState() => _AnimatedRankingCardState();
}

class _AnimatedRankingCardState extends State<_AnimatedRankingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Animation Choc + Ressort (inchangée car vous l'aimiez)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.92),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 80,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerAnimation() {
    _controller.reset();
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isBest = widget.badge == RankBadge.best;
    final isNominated = widget.badge == RankBadge.nominated;
    final accentColor = isBest
        ? Colors.amber
        : isNominated
            ? Colors.lightBlueAccent
            : Colors.transparent;

    return GestureDetector(
      onTap: () {
        _triggerAnimation(); // L'animation s'active pour TOUS
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isBest
                    ? Colors.amber.withOpacity(0.15)
                    : isNominated
                        ? Colors.lightBlueAccent.withOpacity(0.12)
                        : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isBest || isNominated ? accentColor : Colors.transparent,
                  width: 2,
                ),
                boxShadow: (isBest || isNominated)
                    ? [
                        BoxShadow(
                          color: accentColor.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBest || isNominated)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBest ? Icons.emoji_events : Icons.star_outline,
                        size: 12,
                        color: accentColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isBest ? "Meilleur Agent ${widget.periodLabel}" : "Nominé ${widget.periodLabel}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                // CERCLE DU RANG
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isBest ? Colors.amber : Colors.white10,
                  child: Text(
                    "${widget.rank}",
                    style: TextStyle(
                      color: isBest ? Colors.black : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // INFO AGENT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.emp['nom']} ${widget.emp['prenom']}",
                        style: TextStyle(
                          color: isBest
                              ? Colors.amber
                              : isNominated
                                  ? Colors.lightBlueAccent
                                  : (widget.displayScore > 0 ? Colors.white : Colors.white38),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        "${widget.emp['fonction']} • ${widget.emp['ville']}",
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      if (widget.displayScore <= 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.remove_circle_outline, size: 10, color: Colors.white38),
                              SizedBox(width: 3),
                              Text("Pas de note", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                // SCORE DE LA PÉRIODE SÉLECTIONNÉE (même base que le badge).
                // Un agent sans note est distingué visuellement (— en gris)
                // plutôt que d'afficher "0.0 pts", pour ne pas le confondre
                // avec un agent réellement mal noté.
                Text(
                  widget.displayScore > 0 ? "${widget.displayScore.toStringAsFixed(1)} pts" : "—",
                  style: TextStyle(
                      color: isBest
                        ? Colors.amber
                        : isNominated
                            ? Colors.lightBlueAccent
                            : (widget.displayScore > 0 ? Colors.white : Colors.white38),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- VUE PRINCIPALE (Inchangée) ---
class ScoreView extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> allCityEmployees;

  const ScoreView({
    super.key,
    required this.employees,
    required this.allCityEmployees,
  });

  @override
  State<ScoreView> createState() => _ScoreViewState();
}

class _ScoreViewState extends State<ScoreView> {
  OverlayEntry? _overlayEntry;
  String _searchQuery = ''; // ← AJOUTER
  final _searchCtrl = TextEditingController(); // ← AJOUTER

  // Mois / année actuellement affichés dans les deux panneaux.
  // Par défaut : mois et année en cours. On reste sur l'année en cours
  // (navigation possible uniquement de Janvier à Décembre de cette année).
  int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;
  // "Tous" : classement basé sur le cumul de toutes les évaluations
  // (mêmes principe que le sélecteur de director_view.dart).
  bool _showAllMonths = false;

  static const List<String> _kMonthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  double _calculateTotalScore(Map<String, dynamic> emp) {
    final evaluations = emp['evaluations'] as List? ?? [];
    if (evaluations.isEmpty) return 0.0;
    return evaluations.fold(0.0, (sum, eval) => sum + (eval['score'] ?? 0.0));
  }

  /// Score de la période actuellement sélectionnée pour cet agent : cumul
  /// total si "Tous" est actif, sinon score du mois/année sélectionné.
  double _scoreForSelectedPeriod(Map<String, dynamic> emp) {
    return _showAllMonths
        ? _calculateTotalScore(emp)
        : _calculateScoreForMonth(emp, _selectedMonth, _selectedYear);
  }

  /// Liste des évaluations d'un agent qui tombent dans le mois/année donné.
  List<dynamic> _evaluationsForMonth(
    Map<String, dynamic> emp,
    int month,
    int year,
  ) {
    final evaluations = emp['evaluations'] as List? ?? [];
    if (evaluations.isEmpty) return const [];
    return evaluations.where((eval) {
      final rawDate = eval['created_at'] as String? ?? '';
      if (rawDate.isEmpty) return false;
      final evalDate = DateTime.tryParse(rawDate);
      if (evalDate == null) return false;
      return evalDate.year == year && evalDate.month == month;
    }).toList();
  }

  /// Score combiné des évaluations d'un agent pour un mois/année donné.
  double _calculateScoreForMonth(
    Map<String, dynamic> emp,
    int month,
    int year,
  ) {
    final monthEvaluations = _evaluationsForMonth(emp, month, year);
    if (monthEvaluations.isEmpty) return 0.0;
    return monthEvaluations.fold(
      0.0,
      (sum, eval) => sum + ((eval['score'] ?? 0.0) as num).toDouble(),
    );
  }

  void _showOverlay(BuildContext context, Offset position, Map<String, dynamic> evaluation) {
  _hideOverlay();
  final items = evaluation['items_evalues'] as List? ?? [];

  // Hauteur estimée du popup
  const popupHeight = 320.0;
  const popupWidth = 380.0;
  final screenHeight = MediaQuery.of(context).size.height;
  final screenWidth = MediaQuery.of(context).size.width;

  // Si le popup dépasse en bas → l'afficher AU DESSUS du curseur
  double top = position.dy + 10;
  if (top + popupHeight > screenHeight) {
    top = position.dy - popupHeight - 10;
  }

  // Si le popup dépasse à droite → le décaler à gauche
  double left = position.dx + 10;
  if (left + popupWidth > screenWidth) {
    left = screenWidth - popupWidth - 10;
  }

  _overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: _buildModernPopup(items),
      ),
    ),
  );
  Overlay.of(context).insert(_overlayEntry!);
}
  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildModernPopup(List<dynamic> items) {
  return Container(
    width: 380,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF16122D).withOpacity(0.97),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 20,
          spreadRadius: 5,
        )
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.assignment_turned_in_outlined, color: Colors.purpleAccent, size: 18),
          SizedBox(width: 8),
          Text(
            "Détails de l'évaluation",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ]),
        const Divider(color: Colors.white10, height: 20),
        if (items.isEmpty)
          const Text("Aucun détail enregistré.", style: TextStyle(color: Colors.white54))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                final critere = item['critere'] ?? '—';
                final choix = item['choix'] ?? '—';
                final score = (item['score'] ?? 0.0) as num;

                // Couleur selon le score
                Color scoreColor;
                if (score >= 3.0) scoreColor = Colors.greenAccent;
                else if (score >= 1.5) scoreColor = Colors.orangeAccent;
                else scoreColor = Colors.redAccent;

                // Emoji du critère
                final emoji = _kCriteria.firstWhere(
                  (c) => c['title'] == critere,
                  orElse: () => {'emoji': '📋'},
                )['emoji'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$emoji $critere : ",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          choix,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scoreColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          score.toStringAsFixed(1),
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}
  @override
  void dispose() {
    _hideOverlay();
     _searchCtrl.dispose(); // ← AJOUTER
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.employees.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Aucun agent disponible pour cette ville / service.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }
    
    // ← AJOUTER juste avant return Scaffold
final filteredEmployees = widget.employees.where((emp) {
  if (_searchQuery.isEmpty) return true;
  final q = _searchQuery.toLowerCase();
  return (emp['nom'] ?? '').toLowerCase().contains(q) ||
      (emp['prenom'] ?? '').toLowerCase().contains(q);
}).toList();

   // Liste alphabétique (nom puis prénom) pour le panneau "Historique des évaluations"
final alphabeticalEmployees = List<Map<String, dynamic>>.from(filteredEmployees)
  ..sort((a, b) {
    final nomCompare = (a['nom'] ?? '').toString().toLowerCase()
        .compareTo((b['nom'] ?? '').toString().toLowerCase());
    if (nomCompare != 0) return nomCompare;
    return (a['prenom'] ?? '').toString().toLowerCase()
        .compareTo((b['prenom'] ?? '').toString().toLowerCase());
  });

   List<Map<String, dynamic>> rankedList = List.from(filteredEmployees); // ← utiliser filteredEmployees
// Le classement reste trié par meilleure note, calculée sur la période
// sélectionnée (mois précis, ou cumul si "Tous").
rankedList.sort(
  (a, b) => _scoreForSelectedPeriod(b).compareTo(_scoreForSelectedPeriod(a)),
);

// Meilleur score de la période sélectionnée par service, dans la même
// ville (tous services confondus).
final Map<String, double> bestScoreByService = {};
for (final emp in widget.allCityEmployees) {
  final svc = emp['service'] ?? '';
  final periodScore = _scoreForSelectedPeriod(emp);
  if (periodScore <= 0) continue;
  if (!bestScoreByService.containsKey(svc) || periodScore > bestScoreByService[svc]!) {
    bestScoreByService[svc] = periodScore;
  }
}
final double globalBestScore = bestScoreByService.values.isEmpty
    ? 0.0
    : bestScoreByService.values.reduce((a, b) => a > b ? a : b);


    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthSelector(),
            Expanded(
              child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.only(right: 25),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.white10, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader("HISTORIQUE DES ÉVALUATIONS", Icons.history),
const SizedBox(height: 12),
// ← AJOUTER LA BARRE DE RECHERCHE
SizedBox(
  height: 36,
  child: TextField(
    controller: _searchCtrl,
    onChanged: (v) => setState(() => _searchQuery = v),
    style: const TextStyle(color: Colors.white, fontSize: 12),
    decoration: InputDecoration(
      hintText: 'Rechercher par nom ou prénom…',
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
      prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 16),
      suffixIcon: _searchQuery.isNotEmpty
          ? GestureDetector(
              onTap: () => setState(() {
                _searchQuery = '';
                _searchCtrl.clear();
              }),
              child: const Icon(Icons.close, color: Colors.white24, size: 14),
            )
          : null,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    ),
  ),
),
const SizedBox(height: 14),
Expanded(
  child: filteredEmployees.isEmpty
      ? Center(
          child: Text(
            'Aucun résultat pour "$_searchQuery"',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        )
      : ListView.builder(
          itemCount: alphabeticalEmployees.length, // ← tri alphabétique nom/prénom
          itemBuilder: (context, index) {
            final emp = alphabeticalEmployees[index]; // ← tri alphabétique nom/prénom
                          return _buildEmployeeEvaluationHistory(emp);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.only(left: 35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader("CLASSEMENT GLOBAL", Icons.leaderboard),
                    const SizedBox(height: 25),
                    Expanded(
                      child: ListView.builder(
                        itemCount: rankedList.length,
                        itemBuilder: (context, index) {
                          final emp = rankedList[index];
                          final empPeriodScore = _scoreForSelectedPeriod(emp);
                          final empService = emp['service'] ?? '';
                          final bestOfEmpService = bestScoreByService[empService];
                          final isBestOfService = empPeriodScore > 0 &&
                              bestOfEmpService != null &&
                              empPeriodScore == bestOfEmpService;
                          final isBestOfCity = isBestOfService &&
                              globalBestScore > 0 &&
                              empPeriodScore == globalBestScore;

                          final badge = isBestOfCity
                              ? RankBadge.best
                              : isBestOfService
                                  ? RankBadge.nominated
                                  : RankBadge.none;

                          return _AnimatedRankingCard(
                            rank: index + 1,
                            emp: emp,
                            displayScore: empPeriodScore,
                            badge: badge,
                            periodLabel: _showAllMonths ? "(toutes périodes)" : "du mois",
                            onTap: () {
                              print("Clic sur : ${emp['nom']}");
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final isCurrentMonth = _selectedMonth == DateTime.now().month &&
        _selectedYear == DateTime.now().year;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Colors.purpleAccent, size: 18),
          const SizedBox(width: 10),
          const Text(
            "Période affichée :",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 8),
          // Chip "Tous" : cumul de toutes les évaluations (même principe
          // que le sélecteur de mois de director_view.dart).
          ChoiceChip(
            label: const Text("Tous"),
            selected: _showAllMonths,
            onSelected: (_) => setState(() => _showAllMonths = true),
            backgroundColor: const Color(0xFF16122D),
            selectedColor: Colors.amber.withOpacity(0.18),
            labelStyle: TextStyle(
              color: _showAllMonths ? Colors.amber : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _showAllMonths ? Colors.amber : Colors.white12),
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: _showAllMonths ? 0.4 : 1.0,
            child: IgnorePointer(
              ignoring: _showAllMonths,
              child: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white54, size: 20),
                tooltip: 'Mois précédent',
                onPressed: _selectedMonth > 1
                    ? () => setState(() {
                          _selectedMonth--;
                          _showAllMonths = false;
                        })
                    : null,
              ),
            ),
          ),
          Opacity(
            opacity: _showAllMonths ? 0.4 : 1.0,
            child: IgnorePointer(
              ignoring: _showAllMonths,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedMonth,
                    dropdownColor: const Color(0xFF16122D),
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    iconEnabledColor: Colors.purpleAccent,
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text("${_kMonthNames[m - 1]} $_selectedYear"),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedMonth = v;
                          _showAllMonths = false;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: _showAllMonths ? 0.4 : 1.0,
            child: IgnorePointer(
              ignoring: _showAllMonths,
              child: IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                tooltip: 'Mois suivant',
                onPressed: _selectedMonth < 12
                    ? () => setState(() {
                          _selectedMonth++;
                          _showAllMonths = false;
                        })
                    : null,
              ),
            ),
          ),
          const Spacer(),
          if (!isCurrentMonth || _showAllMonths)
            TextButton.icon(
              onPressed: () => setState(() {
                _selectedMonth = DateTime.now().month;
                _showAllMonths = false;
              }),
              icon: const Icon(Icons.today, size: 14, color: Colors.orangeAccent),
              label: const Text(
                "Revenir au mois actuel",
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF8C00), size: 18),
        const SizedBox(width: 12),
        Text(

          title,
          style: const TextStyle(
            color: Color(0xFFFF8C00),
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeEvaluationHistory(Map<String, dynamic> emp) {
    // Uniquement les évaluations du mois/année sélectionné.
    final evaluations = _evaluationsForMonth(emp, _selectedMonth, _selectedYear);
    final monthScore = _calculateScoreForMonth(emp, _selectedMonth, _selectedYear);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ExpansionTile(
        iconColor: Colors.purpleAccent,
        collapsedIconColor: Colors.white24,
        title: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.purpleAccent.withOpacity(0.2),
              child: Text(
                emp['nom'][0],
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "${emp['nom']} ${emp['prenom']}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              "${monthScore.toStringAsFixed(1)} pts",
              style: const TextStyle(
                color: Colors.purpleAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Text(
          "${emp['fonction']} • ${emp['ville']} • ${emp['service']}",
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        children: evaluations.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Aucune évaluation enregistrée pour ${_kMonthNames[_selectedMonth - 1]} $_selectedYear",
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ]
            : [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(
                        label: Text('Date', style: TextStyle(color: Colors.white)),
                      ),
                      DataColumn(
                        label: Text('Évaluateur', style: TextStyle(color: Colors.white)),
                      ),
                      DataColumn(
                        label: Text('Score', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                    rows: evaluations.map((eval) {
                      print('EVAL COMPLET: $eval'); // ← AJOUTER ICI temporairement
         // ↓ AJOUTER CES LIGNES ICI (juste avant le return DataRow)
  final rawDate = eval['created_at'] ?? '';
  final parts = rawDate.isNotEmpty ? rawDate.substring(0, 10).split('-') : [];
  final formattedDate = parts.length == 3
      ? '${parts[2]}/${parts[1]}/${parts[0]}'
      : '—';

  return DataRow(
    cells: [
      DataCell(
        Text(
          formattedDate, // ✅ AVANT : eval['date'] ?? ''
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      DataCell(
        Text(
          eval['evaluateur'] ?? '—', // ✅ AVANT : eval['evaluator'] ?? ''
          style: const TextStyle(color: Colors.white70),
        ),
      ),
                          DataCell(
                            Builder(
                              builder: (BuildContext cellContext) {
                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (event) {
                                    final RenderBox box = cellContext.findRenderObject() as RenderBox;
                                    final offset = box.localToGlobal(Offset.zero);
                                    _showOverlay(context, offset, eval as Map<String, dynamic>);
                                  },
                                  onExit: (event) {
                                    _hideOverlay();
                                  },
                                  child: Text(
                                    (eval['score'] ?? 0.0).toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.purpleAccent,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.purpleAccent,
                                    ),
                                  ),
                                );
                              }
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
      ),
    );
  }
}