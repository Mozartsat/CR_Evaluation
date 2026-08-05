import 'package:flutter/material.dart';
import 'auth_manager.dart';
import 'employee_repository.dart';

class SuiviEvaluationsView extends StatefulWidget {
  const SuiviEvaluationsView({super.key});

  @override
  State<SuiviEvaluationsView> createState() => _SuiviEvaluationsViewState();
}

class _SuiviEvaluationsViewState extends State<SuiviEvaluationsView> {
  DateTime _moisAffiche = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _dateSelectionnee = DateTime.now();
  bool _isLoading = true;
  // date_evaluation ("AAAA-MM-JJ") → évaluations de ce jour (avec agent joint).
  Map<String, List<Map<String, dynamic>>> _evaluationsParDate = {};

  static const List<String> _joursSemaine = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const List<String> _moisNoms = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  /// Villes/services à interroger selon le rôle connecté : sup et rep
  /// restent cantonnés à leur périmètre habituel, admin voit tout.
  List<Map<String, String?>> get _perimetre {
    if (AuthManager.currentUserRole == 'admin') {
      return const [
        {'ville': 'PNR', 'service': null},
        {'ville': 'BZV', 'service': null},
      ];
    }
    final ville = AuthManager.currentUserCity;
    final services = AuthManager.currentUserServices;
    if (services.isEmpty) return [{'ville': ville, 'service': null}];
    return services.map((s) => {'ville': ville, 'service': s}).toList();
  }

  Future<void> _charger() async {
    setState(() => _isLoading = true);
    final Map<String, List<Map<String, dynamic>>> parDate = {};
    try {
      for (final p in _perimetre) {
        final results = await EmployeeRepository.instance.rechercherEvaluations(
          ville: p['ville']!,
          service: p['service'],
        );
        for (final eval in results) {
          final d = (eval['date_evaluation'] ?? '').toString();
          if (d.isEmpty) continue;
          parDate.putIfAbsent(d, () => []).add(eval);
        }
      }
      if (mounted) setState(() => _evaluationsParDate = parDate);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement : $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _iso(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _formatDateFr(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  Map<String, dynamic> _agentDe(Map<String, dynamic> eval) {
    final raw = eval['agents'];
    if (raw is List && raw.isNotEmpty) return Map<String, dynamic>.from(raw.first as Map);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'nom': '—', 'prenom': ''};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;
        final calendrier = _buildCalendrier();
        final liste = _buildListeDuJour();
        if (isNarrow) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [calendrier, const SizedBox(height: 24), SizedBox(height: 420, child: liste)],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 380, child: calendrier),
            const SizedBox(width: 24),
            Expanded(child: liste),
          ],
        );
      },
    );
  }

  Widget _buildCalendrier() {
    final premierJourMois = DateTime(_moisAffiche.year, _moisAffiche.month, 1);
    final nbJours = DateTime(_moisAffiche.year, _moisAffiche.month + 1, 0).day;
    // weekday: 1=lundi ... 7=dimanche → décalage pour aligner sur une
    // grille commençant le lundi.
    final decalage = premierJourMois.weekday - 1;
    final aujourdHui = DateTime.now();

    final cellules = <Widget>[];
    for (int i = 0; i < decalage; i++) {
      cellules.add(const SizedBox());
    }
    for (int jour = 1; jour <= nbJours; jour++) {
      final date = DateTime(_moisAffiche.year, _moisAffiche.month, jour);
      final iso = _iso(date);
      final aDesEvals = _evaluationsParDate.containsKey(iso);
      final estSelectionne = _iso(_dateSelectionnee) == iso;
      final estAujourdHui = _iso(aujourdHui) == iso;

      cellules.add(
        GestureDetector(
          onTap: () => setState(() => _dateSelectionnee = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: estSelectionne
                  ? Colors.purpleAccent
                  : (estAujourdHui ? Colors.purpleAccent.withOpacity(0.15) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: estAujourdHui && !estSelectionne
                  ? Border.all(color: Colors.purpleAccent.withOpacity(0.5))
                  : null,
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$jour",
                  style: TextStyle(
                    color: estSelectionne ? Colors.white : Colors.white70,
                    fontWeight: estSelectionne || estAujourdHui ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                if (aDesEvals)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: estSelectionne ? Colors.white : Colors.cyanAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16122D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white54),
                onPressed: () => setState(() {
                  _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month - 1);
                }),
              ),
              Expanded(
                child: Text(
                  "${_moisNoms[_moisAffiche.month - 1]} ${_moisAffiche.year}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white54),
                onPressed: () => setState(() {
                  _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month + 1);
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: _joursSemaine
                .map((j) => Expanded(
                      child: Center(
                        child: Text(j, style: const TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            children: cellules,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _dateSelectionnee = DateTime.now();
                _moisAffiche = DateTime(DateTime.now().year, DateTime.now().month);
              }),
              icon: const Icon(Icons.today, size: 14, color: Colors.orangeAccent),
              label: const Text("Aujourd'hui", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeDuJour() {
    final iso = _iso(_dateSelectionnee);
    final liste = List<Map<String, dynamic>>.from(_evaluationsParDate[iso] ?? const []);
    // Le score reste caché pour les superviseurs, comme partout ailleurs :
    // ils évaluent mais ne consultent pas les notes.
    final montrerScore = AuthManager.currentUserRole != 'sup';

    liste.sort((a, b) {
      final an = "${_agentDe(a)['nom']} ${_agentDe(a)['prenom']}";
      final bn = "${_agentDe(b)['nom']} ${_agentDe(b)['prenom']}";
      return an.toLowerCase().compareTo(bn.toLowerCase());
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16122D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_outlined, color: Colors.purpleAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Liste des agents évalués — ${_formatDateFr(_dateSelectionnee)}",
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("${liste.length}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: liste.isEmpty
                ? const Center(
                    child: Text("Aucune évaluation ce jour-là.", style: TextStyle(color: Colors.white38, fontSize: 13)),
                  )
                : ListView.separated(
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final eval = liste[index];
                      final agent = _agentDe(eval);
                      final score = (eval['score'] ?? 0.0) as num;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.purpleAccent.withOpacity(0.15),
                              child: Text(
                                (agent['nom'] ?? '?').toString().isNotEmpty
                                    ? agent['nom'][0].toString().toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${agent['nom'] ?? ''} ${agent['prenom'] ?? ''}",
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    "${agent['service'] ?? ''} • évaluateur : ${eval['evaluateur'] ?? '—'}"
                                    "${(eval['vacation'] ?? '').toString().isNotEmpty ? ' • vacation ${eval['vacation']}' : ''}",
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (montrerScore)
                              Text(
                                "${score.toStringAsFixed(1)} pts",
                                style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13),
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
}