import 'package:flutter/material.dart';
import 'employee_repository.dart';
import 'package:flutter/services.dart';

class EvaluationPersonnelView extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final String targetVille;
  final String targetService;
  final Future<void> Function() onUpdate;

  const EvaluationPersonnelView({
    super.key,
    required this.employees,
    required this.targetVille,
    required this.targetService,
    required this.onUpdate,
  });

  @override
  State<EvaluationPersonnelView> createState() =>
      _EvaluationPersonnelViewState();
}

class _EvaluationPersonnelViewState extends State<EvaluationPersonnelView> {
  final Set<String> _selectedForCancel = {};
  final FocusNode _focusNode = FocusNode();
  bool _isControlDown = false;
  String _searchQuery = '';
final _searchCtrl = TextEditingController();


  // Champs de session
  final _vacationController = TextEditingController();
  final _evaluateurController = TextEditingController();
  DateTime _sessionDate = DateTime.now();

  // --- Recherche / modification d'une évaluation déjà enregistrée ---
  bool _showEditSearch = false;
  DateTime? _editSearchDate;
  final _editVacationCtrl = TextEditingController();
  final _editEvaluateurCtrl = TextEditingController();
  final _editAgentCtrl = TextEditingController(); // ← AJOUTER : filtre par nom/prénom d'agent
  bool _isSearchingEdit = false;
  bool _hasSearchedEdit = false;
  List<Map<String, dynamic>> _editSearchResults = [];

  bool get _sessionReady =>
      _vacationController.text.trim().isNotEmpty &&
      _evaluateurController.text.trim().isNotEmpty;

  List<Map<String, dynamic>> get _filteredEmployees => widget.employees
      .where(
        (e) =>
            e['ville'] == widget.targetVille &&
            e['service'] == widget.targetService,
      )
      .toList();

  final List<Map<String, dynamic>> _criteria = [
    {
      'title': 'Ponctualité',
      'emoji': '⏰',
      'options': [
        {'text': 'H+7 à 15mn', 'emoji': '😴', 'score': 0.0},
        {'text': 'Au-delà de 15mn', 'emoji': '😫', 'score': 0.0},
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _vacationController.dispose();
    _evaluateurController.dispose();
    _searchCtrl.dispose(); // ← AJOUTER
    _editVacationCtrl.dispose();
    _editEvaluateurCtrl.dispose();
    _editAgentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }
   
  int _compareByNomPrenom(Map<String, dynamic> a, Map<String, dynamic> b) {
    final nomCompare = (a['nom'] ?? '').toString().toLowerCase()
        .compareTo((b['nom'] ?? '').toString().toLowerCase());
    if (nomCompare != 0) return nomCompare;
    return (a['prenom'] ?? '').toString().toLowerCase()
        .compareTo((b['prenom'] ?? '').toString().toLowerCase());
  }

  bool _estSuperviseur(Map<String, dynamic> emp) {
    return (emp['fonction'] ?? '').toString().trim().toLowerCase() ==
        'superviseur';
  }

  void _handleKeyEvent(KeyEvent event) {
  final isControlPressed = HardwareKeyboard.instance.isControlPressed;
  if (_isControlDown != isControlPressed) {
    setState(() => _isControlDown = isControlPressed);
  }
 }

  InputDecoration _sessionFieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      prefixIcon: Icon(icon, color: Colors.white38, size: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  void _showCancelDialog(Map<String, dynamic> emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        title: Text(
          "Annuler l'évaluation de l'agent ${emp['nom']} ${emp['prenom']}",
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Voulez-vous vraiment annuler cette évaluation ?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Non", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                emp['isValidated'] = false;
                emp['evaluationScore'] = null;
                emp['evaluationSelections'] = null;
              });
              await EmployeeRepository.instance.init();
              widget.onUpdate();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Oui"),
          ),
        ],
      ),
    );
  }

  void _showFinishSessionDialog(
    List<Map<String, dynamic>> evaluatedEmployees, {
    Set<String> recalages = const {},
    String raisonRecalage = "Agent recalé",
  }) {
    final total = evaluatedEmployees.length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool saving = false;
        int savedCount = 0;
        return StatefulBuilder(
          builder: (ctx2, setDialogState) => AlertDialog(
              backgroundColor: const Color(0xFF16122D),
              title: Text(
                saving ? "Enregistrement en cours…" : "Terminer la session d'évaluation",
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: saving
                    ? [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: total == 0 ? null : savedCount / total,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "$savedCount / $total agent(s) enregistré(s)…",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Merci de patienter, ne fermez pas cette fenêtre.",
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ]
                    : [
                        _infoRow(Icons.calendar_today, "Date",
                            "${_sessionDate.day.toString().padLeft(2, '0')}/${_sessionDate.month.toString().padLeft(2, '0')}/${_sessionDate.year}"),
                        const SizedBox(height: 8),
                        _infoRow(Icons.schedule, "Vacation", _vacationController.text.trim()),
                        const SizedBox(height: 8),
                        _infoRow(Icons.person_outline, "Évaluateur", _evaluateurController.text.trim()),
                        const SizedBox(height: 16),
                        Text(
                          "$total agent(s) évalué(s)",
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        if (recalages.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            "${recalages.length} recalage(s) : « $raisonRecalage »",
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                          ),
                        ],
                      ],
              ),
              actions: saving
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("ANNULER", style: TextStyle(color: Colors.white70)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setDialogState(() => saving = true);
                          _finishSession(
                            evaluatedEmployees,
                            _evaluateurController.text.trim(),
                            ctx,
                            recalages: recalages,
                            raisonRecalage: raisonRecalage,
                            onProgress: (completed, t) {
                              if (ctx.mounted) {
                                setDialogState(() => savedCount = completed);
                              }
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                        ),
                        child: const Text("TERMINER"),
                      ),
                    ],
            ),
          );
        },
      );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.white38),
      const SizedBox(width: 8),
      Text("$label : ", style: const TextStyle(color: Colors.white54, fontSize: 12)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }

  bool _dansLes48h(DateTime? date) {
    if (date == null) return false;
    final debut = DateTime(date.year, date.month, date.day);
    return DateTime.now().difference(debut).inHours <= 48;
  }

  /// Vérifie si la date visée est utilisable (soit < 48h, soit débloquée
  /// par un Rep/DEX/Admin) pour ce service/ville, et éventuellement cette
  /// vacation précise.
  Future<bool> _dateAutorisee(DateTime date, {String? vacation}) async {
    if (_dansLes48h(date)) return true;
    return EmployeeRepository.instance.estDebloque(
      ville: widget.targetVille,
      service: widget.targetService,
      dateCible: date,
      vacation: vacation,
    );
  }

  void _showVerrouPopup({required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.lock_outline, color: Colors.redAccent, size: 40),
        title: const Text(
          "Action bloquée",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              child: const Text("COMPRIS"),
            ),
          ),
        ],
      ),
    );
  }

  /// Alerte le sup que certains agents de la session sont déjà évalués ce
  /// jour (recalage potentiel), et lui demande une raison avant de continuer.
  /// Retourne la raison saisie si confirmé, null si annulé.
  Future<String?> _showRecalagePopup(List<Map<String, dynamic>> agents) async {
    final raisonCtrl = TextEditingController(text: "Agent recalé");
    final noms = agents.map((e) => "${e['nom']} ${e['prenom']}").join(', ');
    final isSingle = agents.length == 1;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 40),
        title: Text(
          isSingle
              ? "L'agent : $noms est déjà évalué ce jour"
              : "Les agents : $noms sont déjà évalués ce jour",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Seule la meilleure note du jour sera conservée pour chacun d'eux.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: raisonCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: "Raison pour la seconde évaluation",
                labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text("Continuer"),
          ),
        ],
      ),
    );

    if (confirme != true) return null;
    final raison = raisonCtrl.text.trim();
    return raison.isEmpty ? "Agent recalé" : raison;
  }

  void _showRapportSessionPopup(
    List<Map<String, dynamic>> employees,
    Map<String, ResultatEnregistrementEvaluation> rapport,
  ) {
    final inseres = <String>[];
    final recalages = <String>[];
    final ignores = <String>[];

    for (final emp in employees) {
      final nom = "${emp['nom']} ${emp['prenom']}";
      switch (rapport[emp['id']]) {
        case ResultatEnregistrementEvaluation.insere:
          inseres.add(nom);
          break;
        case ResultatEnregistrementEvaluation.recalageNouvelleNoteConservee:
          recalages.add(nom);
          break;
        case ResultatEnregistrementEvaluation.recalageAncienneNoteConservee:
          recalages.add("$nom (note précédente déjà meilleure, conservée)");
          break;
        case ResultatEnregistrementEvaluation.quotaAtteintIgnore:
          ignores.add(nom);
          break;
        default:
          break;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.fact_check_outlined, color: Colors.greenAccent, size: 40),
        title: const Text(
          "Session terminée",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inseres.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "✅ Enregistrées : ${inseres.join(', ')}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            if (recalages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "🔁 Recalage (meilleure note conservée) : ${recalages.join(', ')}",
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
            if (ignores.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "⛔ Ignorées (quota mensuel atteint) : ${ignores.join(', ')}",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              child: const Text("OK"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFinishSessionDialogGuarded(
    List<Map<String, dynamic>> evaluatedEmployees,
  ) async {
    final autorise = await _dateAutorisee(
      _sessionDate,
      vacation: _vacationController.text.trim(),
    );
    if (!autorise) {
      _showVerrouPopup(
        message:
            "Cette session date de plus de 48h "
            "(${_sessionDate.day.toString().padLeft(2, '0')}/${_sessionDate.month.toString().padLeft(2, '0')}/${_sessionDate.year} · "
            "vacation « ${_vacationController.text.trim()} »).\n\n"
            "Demandez à un Rep, un DEX ou un Admin de débloquer cette date "
            "avant de pouvoir enregistrer ces évaluations.",
      );
      return;
    }

    // Détection des agents déjà évalués ce jour (recalage potentiel).
    final idsSession = evaluatedEmployees.map((e) => e['id'].toString()).toList();
    final idsDejaEvalues = await EmployeeRepository.instance.agentsDejaEvaluesCeJour(
      agentIds: idsSession,
      date: _sessionDate,
    );

    Set<String> recalages = {};
    String raisonRecalage = "Agent recalé";

    if (idsDejaEvalues.isNotEmpty) {
      final agentsConcernes = evaluatedEmployees
          .where((e) => idsDejaEvalues.contains(e['id'].toString()))
          .toList();
      final raison = await _showRecalagePopup(agentsConcernes);
      if (raison == null) return; // annulé par le sup
      raisonRecalage = raison;
      recalages = idsDejaEvalues.toSet();
    }

    _showFinishSessionDialog(
      evaluatedEmployees,
      recalages: recalages,
      raisonRecalage: raisonRecalage,
    );
  }

  void _finishSession(
    List<Map<String, dynamic>> evaluatedEmployees,
    String evaluator,
    BuildContext dialogContext, {
    Set<String> recalages = const {},
    String raisonRecalage = "Agent recalé",
    void Function(int completed, int total)? onProgress,
  }) async {
    final rapport = <String, ResultatEnregistrementEvaluation>{};
    final total = evaluatedEmployees.length;

    try {
      for (int idx = 0; idx < evaluatedEmployees.length; idx++) {
        final emp = evaluatedEmployees[idx];
        final List<int?> selections = List<int?>.from(emp['evaluationSelections']);
        final List<Map<String, dynamic>> items = [];

        for (int i = 0; i < _criteria.length; i++) {
          final selectedIndex = selections[i];
          if (selectedIndex != null) {
            final option = _criteria[i]['options'][selectedIndex];
            items.add({
              'critere': _criteria[i]['title'],
              'choix': option['text'],
              'score': option['score'],
            });
          }
        }

        final estRecalage = recalages.contains(emp['id'].toString());
        final resultat = await EmployeeRepository.instance.enregistrerEvaluationControlee(
          agentId: emp['id'],
          scoreTotal: emp['evaluationScore'],
          items: items,
          evaluateur: evaluator,
          vacation: _vacationController.text.trim(),
          dateEvaluation: _sessionDate,
          commentaire: estRecalage ? raisonRecalage : null,
        );
        rapport[emp['id'].toString()] = resultat;
        onProgress?.call(idx + 1, total);
      }
    } catch (e) {
      // Le dialog de chargement doit disparaître même si une évaluation échoue.
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur pendant l'enregistrement : $e")),
        );
      }
      return;
    }

    final employeesPourRapport =
        evaluatedEmployees.map((e) => Map<String, dynamic>.from(e)).toList();

    for (var emp in evaluatedEmployees) {
      emp['isValidated'] = false;
      emp['evaluationScore'] = null;
      emp['evaluationSelections'] = null;
    }

    // dialogContext.mounted : vérifie que ce context précis (le dialog)
    // est toujours dans l'arbre avant de le fermer, indépendamment du
    // State de l'écran parent.
    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }

    await widget.onUpdate();

    if (mounted) {
      setState(() {});
      _showRapportSessionPopup(employeesPourRapport, rapport);
    }
  }

  
  void _openEvaluationSheet(Map<String, dynamic> emp) {
    if (_estSuperviseur(emp)) return; // sécurité supplémentaire
    showDialog(
      context: context,
      builder: (ctx) => EvaluationDialog(
        employee: emp,
        criteria: _criteria,
        onValidate: (selections) {
          double totalScore = 0.0;
          for (int i = 0; i < _criteria.length; i++) {
            if (selections[i] != null) {
              totalScore += _criteria[i]['options'][selections[i]]['score'];
            }
          }
          emp['evaluationScore'] = totalScore;
          emp['evaluationSelections'] = selections;
          setState(() => emp['isValidated'] = true);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _cancelMultipleEvaluations() {
    for (var emp in _filteredEmployees) {
      if (_selectedForCancel.contains(emp['id'])) {
        emp['isValidated'] = false;
        emp['evaluationScore'] = null;
        emp['evaluationSelections'] = null;
      }
    }
    _selectedForCancel.clear();
    widget.onUpdate();
    setState(() {});
  }

  // ============================================================
  //   RECHERCHE / MODIFICATION D'UNE ÉVALUATION DÉJÀ ENREGISTRÉE
  // ============================================================

  Future<void> _rechercherEvaluationsAModifier() async {
    setState(() {
      _isSearchingEdit = true;
      _hasSearchedEdit = true;
    });
    try {
      final results = await EmployeeRepository.instance.rechercherEvaluations(
        ville: widget.targetVille,
        service: widget.targetService,
        vacation: _editVacationCtrl.text.trim(),
        evaluateur: _editEvaluateurCtrl.text.trim(),
        date: _editSearchDate,
      );

      // Filtre par nom/prénom d'agent (fait côté client : le nom de
      // l'agent vient de la table jointe 'agents', plus simple et fiable
      // à filtrer ici qu'en construisant un filtre PostgREST sur relation).
      final agentQuery = _editAgentCtrl.text.trim().toLowerCase();
      final filtered = agentQuery.isEmpty
          ? results
          : results.where((eval) {
              final agent = _agentDeEvaluation(eval);
              final nom = (agent['nom'] ?? '').toString().toLowerCase();
              final prenom = (agent['prenom'] ?? '').toString().toLowerCase();
              return nom.contains(agentQuery) || prenom.contains(agentQuery);
            }).toList();

      if (mounted) setState(() => _editSearchResults = filtered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche : $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingEdit = false);
    }
  }

  Map<String, dynamic> _agentDeEvaluation(Map<String, dynamic> evaluation) {
    final raw = evaluation['agents'];
    if (raw is List && raw.isNotEmpty) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {'nom': '—', 'prenom': ''};
  }

  List<int?> _selectionsDepuisItems(List<dynamic> items) {
    final selections = List<int?>.filled(_criteria.length, null);
    for (int i = 0; i < _criteria.length; i++) {
      final title = _criteria[i]['title'];
      final match = items.firstWhere(
        (it) => it is Map && it['critere'] == title,
        orElse: () => null,
      );
      if (match != null) {
        final options = _criteria[i]['options'] as List;
        final idx = options.indexWhere((o) => o['text'] == match['choix']);
        if (idx != -1) selections[i] = idx;
      }
    }
    return selections;
  }

  Future<void> _onTapResultatModification(Map<String, dynamic> evaluation) async {
    final rawDate = evaluation['date_evaluation'] as String?;
    final date = rawDate != null ? DateTime.tryParse(rawDate) : null;
    final vacation = evaluation['vacation'] as String?;

    final autorise = date != null &&
        await _dateAutorisee(date, vacation: vacation);

    if (!autorise) {
      _showVerrouPopup(
        message:
            "Cette évaluation date de plus de 48h "
            "(${rawDate ?? '—'} · vacation « ${vacation ?? ''} »).\n\n"
            "Elle ne peut plus être modifiée sans déblocage préalable "
            "d'un Rep, d'un DEX ou d'un Admin.",
      );
      return;
    }
    _openEditDialog(evaluation);
  }

  void _openEditDialog(Map<String, dynamic> evaluation) {
    final items = (evaluation['items_evalues'] as List?) ?? [];
    final initialSelections = _selectionsDepuisItems(items);
    final agentInfo = _agentDeEvaluation(evaluation);

    showDialog(
      context: context,
      builder: (ctx) => EvaluationDialog(
        employee: agentInfo,
        criteria: _criteria,
        initialSelections: initialSelections,
        onValidate: (selections) async {
          double totalScore = 0.0;
          final newItems = <Map<String, dynamic>>[];
          for (int i = 0; i < _criteria.length; i++) {
            if (selections[i] != null) {
              final option = _criteria[i]['options'][selections[i]];
              totalScore += option['score'];
              newItems.add({
                'critere': _criteria[i]['title'],
                'choix': option['text'],
                'score': option['score'],
              });
            }
          }
          try {
            await EmployeeRepository.instance.modifierEvaluation(
              evaluationId: evaluation['id'].toString(),
              scoreTotal: totalScore,
              items: newItems,
            );
            if (mounted) Navigator.pop(ctx);
            await widget.onUpdate();
            await _rechercherEvaluationsAModifier();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Évaluation modifiée avec succès'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = widget.employees
        .where(
          (e) =>
              e['ville'] == widget.targetVille &&
              e['service'] == widget.targetService,
        )
        .toList();
    final listTodoAll = filteredEmployees.where((e) => e['isValidated'] != true).toList();
final listDoneAll = filteredEmployees.where((e) => e['isValidated'] == true).toList();

final listTodo = listTodoAll.where((e) {
  if (_searchQuery.isEmpty) return true;
  final q = _searchQuery.toLowerCase();
  return (e['nom'] ?? '').toLowerCase().contains(q) ||
      (e['prenom'] ?? '').toLowerCase().contains(q);
}).toList()
  ..sort(_compareByNomPrenom);

final listDone = listDoneAll.where((e) {
  if (_searchQuery.isEmpty) return true;
  final q = _searchQuery.toLowerCase();
  return (e['nom'] ?? '').toLowerCase().contains(q) ||
      (e['prenom'] ?? '').toLowerCase().contains(q);
}).toList()
  ..sort(_compareByNomPrenom);

    return KeyboardListener(
  focusNode: _focusNode,
  onKeyEvent: _handleKeyEvent,
  autofocus: true,
  child: Column(
        children: [
          // EN-TÊTE DE SESSION
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.assignment_outlined, size: 16, color: Colors.purpleAccent),
                  const SizedBox(width: 8),
                  const Text(
                    "Session d'évaluation",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${widget.targetVille} › ${widget.targetService}",
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ),
                ]),

                const SizedBox(height: 12),
                Row(children: [
                  // DATE
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _sessionDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.purpleAccent,
                                onPrimary: Colors.white,
                                surface: Color(0xFF16122D),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) setState(() => _sessionDate = d);
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(
                            text:
                                "${_sessionDate.day.toString().padLeft(2, '0')}/${_sessionDate.month.toString().padLeft(2, '0')}/${_sessionDate.year}",
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _sessionFieldDecoration("Date", Icons.calendar_today),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // VACATION
                  Expanded(
                    child: TextField(
                      controller: _vacationController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: (_) => setState(() {}),
                      decoration: _sessionFieldDecoration("Vacation (ex: 06h–14h)", Icons.schedule),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // EVALUATEUR
                  Expanded(
                    child: TextField(
                      controller: _evaluateurController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: (_) => setState(() {}),
                      decoration: _sessionFieldDecoration("Évaluateur", Icons.person_outline),
                    ),
                  ),
                  

                ]),

                   const SizedBox(height: 10),
                 SizedBox(
  height: 34,
  child: TextField(
    controller: _searchCtrl,
    onChanged: (v) => setState(() => _searchQuery = v),
    style: const TextStyle(color: Colors.white, fontSize: 12),
    decoration: InputDecoration(
      hintText: 'Rechercher un agent par nom ou prénom…',
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

                const SizedBox(height: 10),
                       
                Row(children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: _sessionReady ? Colors.greenAccent : Colors.white24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sessionReady
                        ? "Session prête — ${_evaluateurController.text.trim()} · ${_vacationController.text.trim()}"
                        : "Renseignez la vacation et l'évaluateur pour commencer",
                    style: TextStyle(
                      fontSize: 12,
                      color: _sessionReady ? Colors.white70 : Colors.white38,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildEditSearchPanel(),
          const SizedBox(height: 20),
         
         Expanded(
            child: IgnorePointer(
              ignoring: !_sessionReady,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _sessionReady ? 1.0 : 0.35,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildColumn(
                        title: "Liste des agents",
                        count: listTodo.length,
                        color: Colors.orangeAccent,
                        list: listTodo,
                        onTap: (e) => _openEvaluationSheet(e),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildColumn(
                        title: "Évalués",
                        count: listDone.length,
                        color: Colors.greenAccent,
                        list: listDone,
                        isDone: true,
                        selectedIds: _selectedForCancel,
                        onTap: (e) => _showCancelDialog(e),
                        onSelectionChanged: (id, selected) {
                          setState(() {
                            if (selected) {
                              _selectedForCancel.add(id);
                            } else {
                              _selectedForCancel.remove(id);
                            }
                          });
                        },
                      ),
                    ),
                  ], //Child of Row
                ),
              ),
            ),
          ),
          // ← ICI, EN DEHORS du Expanded précédent
          if (listDone.isNotEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _sessionReady
                    ? () => _showFinishSessionDialogGuarded(listDone)
                    : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("TERMINER LA SESSION"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _sessionReady
                      ? const Color(0xFF2E7D32)
                      : Colors.white12,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                   ),
              ),
            ),
          ], // ← ferme if ...[
        ],   // ← ferme children de la Column
      ),     // ← ferme Column
    );       // ← ferme KeyboardListener
  }          // ← ferme build()

  Widget _buildEditSearchPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showEditSearch,
          onExpansionChanged: (v) => setState(() => _showEditSearch = v),
          iconColor: Colors.orangeAccent,
          collapsedIconColor: Colors.white38,
          title: Row(children: const [
            Icon(Icons.history_edu_outlined, size: 16, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text(
              "Modifier une évaluation",
              style: TextStyle(fontSize: 13, color: Colors.white),
            ),
          ]),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _editAgentCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _sessionFieldDecoration("Nom de l'agent", Icons.person_search),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.purpleAccent,
                            onPrimary: Colors.white,
                            surface: Color(0xFF16122D),
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) setState(() => _editSearchDate = d);
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: TextEditingController(
                        text: _editSearchDate == null
                            ? ''
                            : "${_editSearchDate!.day.toString().padLeft(2, '0')}/${_editSearchDate!.month.toString().padLeft(2, '0')}/${_editSearchDate!.year}",
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _sessionFieldDecoration("Date (optionnel)", Icons.calendar_today),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _editVacationCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _sessionFieldDecoration("Vacation", Icons.schedule),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _editEvaluateurCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _sessionFieldDecoration("Évaluateur", Icons.person_outline),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isSearchingEdit ? null : _rechercherEvaluationsAModifier,
                icon: _isSearchingEdit
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.search, size: 16, color: Colors.black),
                label: const Text("Chercher", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _effacerRechercheModification,
                icon: const Icon(Icons.close, size: 18, color: Colors.white38),
                tooltip: "Effacer la recherche",
              ),
            ]),
            const SizedBox(height: 12),
            _buildEditSearchResults(),
          ],
        ),
      ),
    );
  }

  void _effacerRechercheModification() {
    setState(() {
      _editAgentCtrl.clear();
      _editSearchDate = null;
      _editVacationCtrl.clear();
      _editEvaluateurCtrl.clear();
      _hasSearchedEdit = false;
      _editSearchResults = [];
    });
  }

  Widget _buildEditSearchResults() {
    if (!_hasSearchedEdit) {
      return const Text(
        "Lancez une recherche par date, vacation et/ou évaluateur pour retrouver une évaluation.",
        style: TextStyle(color: Colors.white24, fontSize: 11),
      );
    }
    if (_editSearchResults.isEmpty) {
      return const Text(
        "Aucune évaluation trouvée pour ces critères.",
        style: TextStyle(color: Colors.white38, fontSize: 11),
      );
    }
    return Column(
      children: _editSearchResults.map((eval) {
        final agent = _agentDeEvaluation(eval);
        final rawDate = eval['date_evaluation'] as String?;
        final vacation = (eval['vacation'] as String?) ?? '';
        final score = (eval['score'] ?? 0.0) as num;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            tileColor: const Color(0xFF16122D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Text(
              "${agent['nom'] ?? ''} ${agent['prenom'] ?? ''}",
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              "${rawDate ?? '—'} · ${vacation.isEmpty ? 'vacation non renseignée' : vacation} · "
              "évaluateur : ${eval['evaluateur'] ?? '—'}",
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${score.toStringAsFixed(1)} pts",
                  style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined, size: 15, color: Colors.white38),
              ],
            ),
            onTap: () => _onTapResultatModification(eval),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColumn({
    required String title,
    required int count,
    required Color color,
    required List<Map<String, dynamic>> list,
    bool isDone = false,
    Set<String>? selectedIds,
    required Function(Map<String, dynamic>) onTap,
    Function(String, bool)? onSelectionChanged,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Center(
            child: Text(
              "$title ($count)",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        if (isDone && _selectedForCancel.length >= 2) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton.icon(
              onPressed: _cancelMultipleEvaluations,
              icon: const Icon(Icons.undo, color: Colors.white),
              label: Text(
                "Annuler Evaluation (${_selectedForCancel.length})",
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16122D),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: list.length,
              separatorBuilder: (c, i) =>
                  const Divider(color: Colors.white10, height: 1),
              itemBuilder: (c, i) {
                final emp = list[i];
                final isSelected = selectedIds?.contains(emp['id']) ?? false;
                // Les superviseurs sont exemptés d'évaluation : non-cliquables
                // dans la liste "à évaluer".
                final isExempt = !isDone && _estSuperviseur(emp);
                return ListTile(
                  enabled: !isExempt,
                  selected: isSelected,
                  selectedTileColor: Colors.redAccent.withOpacity(0.1),
                  title: Text(
                    "${emp['nom']} ${emp['prenom']}",
                    style: TextStyle(
                      fontSize: 13,
                      color: isExempt ? Colors.white24 : null,
                    ),
                  ),
                  subtitle: Text(
                    isExempt
                        ? "${emp['fonction']} • Exempté d'évaluation"
                        : (emp['fonction'] ?? ''),
                    style: TextStyle(
                      fontSize: 11,
                      color: isExempt ? Colors.white24 : Colors.white38,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isExempt)
                        const Icon(Icons.lock_outline, color: Colors.white24, size: 16)
                      else
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : (isDone ? Icons.check_circle : Icons.arrow_forward_ios),
                          color: isSelected
                              ? Colors.redAccent
                              : (isDone ? Colors.greenAccent : Colors.white24),
                          size: 16,
                        ),
                    ],
                  ),
                  onTap: isExempt
                      ? null
                      : () {
                          if (isDone && _isControlDown) {
                            final selected = !isSelected;
                            onSelectionChanged?.call(emp['id'] as String, selected);
                          } else {
                            if (_selectedForCancel.isNotEmpty && !_isControlDown) {
                              setState(() => _selectedForCancel.clear());
                            }
                            onTap(emp);
                          }
                        },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class EvaluationDialog extends StatefulWidget {
  final Map<String, dynamic> employee;
  final List<Map<String, dynamic>> criteria;
  final Function(List<int?>) onValidate;
  final List<int?>? initialSelections;

  const EvaluationDialog({
    super.key,
    required this.employee,
    required this.criteria,
    required this.onValidate,
    this.initialSelections,
  });

  @override
  State<EvaluationDialog> createState() => _EvaluationDialogState();
}

class _EvaluationDialogState extends State<EvaluationDialog> {
  late List<int?> _selections;

  @override
  void initState() {
    super.initState();
    _selections = widget.initialSelections != null
        ? List<int?>.from(widget.initialSelections!)
        : List<int?>.filled(widget.criteria.length, null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF16122D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Évaluation : ${widget.employee['nom']} ${widget.employee['prenom']}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: widget.criteria.length,
                itemBuilder: (context, index) {
                  final criterion = widget.criteria[index];
                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${criterion['emoji']} ${criterion['title']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purpleAccent,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: List.generate(
                              criterion['options'].length,
                              (optionIndex) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selections[index] = optionIndex;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selections[index] == optionIndex
                                        ? Colors.purpleAccent.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _selections[index] == optionIndex
                                          ? Colors.purpleAccent
                                          : Colors.white24,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        criterion['options'][optionIndex]['emoji'],
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        criterion['options'][optionIndex]['text'],
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: _selections[index] == optionIndex
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "ANNULER",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _selections.every((s) => s != null)
                      ? () => widget.onValidate(_selections)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("VALIDER"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}