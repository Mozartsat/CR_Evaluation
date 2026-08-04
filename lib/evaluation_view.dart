import 'package:flutter/material.dart';
import 'employee_repository.dart';
import 'package:flutter/services.dart';

/// Décrit les champs de session à afficher selon le profil de superviseur
/// (supkppnr / supopspnr / suppistepnr / supgrgpnr / supfretpnr).
class _SessionFieldsConfig {
  final String label1;
  final IconData icon1;
  final List<String> posteOptions;
  final bool showNumeroVol;
  

  const _SessionFieldsConfig({
    required this.label1,
    required this.icon1,
    required this.posteOptions,
    required this.showNumeroVol,
  });
}

/// Une ligne de contexte de session : un GDV/Agent/Chef d'équipe avec SON
/// propre poste et SON propre N° de vol. Plusieurs lignes possibles (ajout
/// via le "+"), ex : 2 GDV en relève sur la même vacation avec des postes
/// différents.
class _SessionEntry {
  final TextEditingController identifiantCtrl = TextEditingController();
  final TextEditingController numeroVolCtrl = TextEditingController();
  String? poste;

  void dispose() {
    identifiantCtrl.dispose();
    numeroVolCtrl.dispose();
  }
}

class EvaluationView extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final String targetVille;
  final String targetService;
  final Future<void> Function() onUpdate;

  const EvaluationView({
    super.key,
    required this.employees,
    required this.targetVille,
    required this.targetService,
    required this.onUpdate,
  });

  @override
  State<EvaluationView> createState() =>
      _EvaluationViewState();
}

class _EvaluationViewState extends State<EvaluationView> {
  final Set<String> _selectedForCancel = {};
  final FocusNode _focusNode = FocusNode();
  bool _isControlDown = false;
  // Permet de replier l'en-tête "Session d'évaluation" (Date/Vacation/
  // Évaluateur + lignes GDV/poste/vol) pour redonner de la place aux listes
  // "Liste des agents" / "Évalués" en dessous. La ligne de statut résumée
  // ("Session prête — ...") reste visible même replié.
  bool _sessionHeaderExpanded = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Champs de session
  final _vacationController = TextEditingController();
  final _evaluateurController = TextEditingController();
  DateTime _sessionDate = DateTime.now();

  // --- Infos complémentaires de session (à renseigner avant de commencer) ---
  // Chaque ligne = un GDV/Agent/Chef d'équipe AVEC son propre poste et son
  // propre N° de vol (ajout d'une nouvelle ligne complète via le "+").
  final List<_SessionEntry> _sessionEntries = [_SessionEntry()];

  // Contrôleur de défilement dédié au panneau de recherche (évite tout
  // conflit de PrimaryScrollController entre plusieurs zones défilantes).
  final ScrollController _searchResultsScrollCtrl = ScrollController();

  // --- Recherche / modification d'une évaluation déjà enregistrée ---
  bool _showEditSearch = false;
  DateTime? _editSearchDate;
  final _editVacationCtrl = TextEditingController();
  final _editEvaluateurCtrl = TextEditingController();
  final _editAgentCtrl = TextEditingController(); // ← AJOUTER : filtre par nom/prénom d'agent
  bool _isSearchingEdit = false;
  bool _hasSearchedEdit = false;
  List<Map<String, dynamic>> _editSearchResults = [];

  /// Configuration des champs de session (1er champ, options "Poste", et
  /// présence ou non du N° de vol) selon le profil de superviseur, déduit
  /// du service ciblé (targetService). Chaque ligne de _sessionEntries
  /// est utilisée pour "GDV" / "Agent" / "Chef d'équipe" / "Agents" selon le
  /// profil : seul le libellé affiché change, la valeur saisie est toujours
  /// persistée dans la colonne `gdv` de la table `evaluations`.
  _SessionFieldsConfig get _fieldsConfig {
    final s = widget.targetService.toLowerCase();
    if (s.contains('piste')) {
      // suppistepnr
      return const _SessionFieldsConfig(
        label1: "Chef d'équipe",
        icon1: Icons.groups_outlined,
        posteOptions: ["Coordination (CZA)", "Tâches Ordinaires (T.O)"],
        showNumeroVol: false,
      );
    }
    if (s.contains('garage')) {
      // supgrgpnr
      return const _SessionFieldsConfig(
        label1: "Agents",
        icon1: Icons.groups_outlined,
        posteOptions: [
          "Visite Préventive (V.P)",
          "Visite Curative (V.C)",
          "Plein Carburant (P.C)",
          "Courses ADM (C.A)",
        ],
        showNumeroVol: false,
      );
    }
    if (s.contains('fret')) {
      // supfretpnr
      return const _SessionFieldsConfig(
        label1: "Chef d'équipe",
        icon1: Icons.groups_outlined,
        posteOptions: [
          "Import (IM)",
          "Export (EX)",
          "Acceptation (AC)",
          "Palletisation (PA)",
          "Transfert Douane (T.D)",
        ],
        showNumeroVol: false,
      );
    }
    if (s.contains('ops')) {
      // supopspnr
      return const _SessionFieldsConfig(
        label1: "Agent",
        icon1: Icons.person_outline,
        posteOptions: [
          "Back Office",
          "Front Office",
          "Ops Service",
          "Vols ADHOC",
        ],
        showNumeroVol: true,
      );
    }
    // Par défaut : supkppnr (GDV / Front Office / Back Office / N° de vol).
    return const _SessionFieldsConfig(
      label1: "GDV",
      icon1: Icons.badge_outlined,
      posteOptions: ["Front Office", "Back Office"],
      showNumeroVol: true,
    );
  }

  bool get _sessionReady {
    final cfg = _fieldsConfig;
    final base = _vacationController.text.trim().isNotEmpty &&
        _evaluateurController.text.trim().isNotEmpty &&
        _sessionEntries.isNotEmpty &&
        _sessionEntries.every((e) =>
            e.identifiantCtrl.text.trim().isNotEmpty &&
            e.poste != null &&
            (!cfg.showNumeroVol || e.numeroVolCtrl.text.trim().isNotEmpty));
    return base;
  }

  /// Valeurs combinées (une par ligne, dans l'ordre) pour les colonnes
  /// `gdv` / `poste` / `numero_vol` de la table `evaluations` — pas de
  /// changement de schéma nécessaire : chaque colonne texte porte la liste
  /// jointe par ", ", dans le même ordre pour les 3 colonnes, ce qui permet
  /// de les réassocier ligne par ligne à l'affichage (popup côté reps).
  String get _gdvCombine =>
      _sessionEntries.map((e) => e.identifiantCtrl.text.trim()).join(', ');
  String get _posteCombine =>
      _sessionEntries.map((e) => e.poste ?? '').join(', ');
  String get _numeroVolCombine => _fieldsConfig.showNumeroVol
      ? _sessionEntries.map((e) => e.numeroVolCtrl.text.trim()).join(', ')
      : '';

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
    for (final e in _sessionEntries) {
      e.dispose();
    }
    _searchResultsScrollCtrl.dispose();
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

  void _ajouterSessionEntry() {
    setState(() => _sessionEntries.add(_SessionEntry()));
  }

  void _retirerSessionEntry(int index) {
    setState(() {
      _sessionEntries[index].dispose();
      _sessionEntries.removeAt(index);
    });
  }

  /// Sélecteur "Poste" pour UNE ligne de session donnée (chaque ligne a son
  /// propre poste, indépendant des autres lignes).
  Widget _posteSelectorForEntry(_SessionEntry entry, List<String> options) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 6,
        runSpacing: 6,
        children: options.map((opt) {
          final selected = entry.poste == opt;
          return GestureDetector(
            onTap: () => setState(() => entry.poste = opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? Colors.purpleAccent.withOpacity(0.25) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? Colors.purpleAccent : Colors.white12,
                ),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.purpleAccent : Colors.white54,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Une ligne complète de contexte de session : identifiant (GDV/Agent/Chef
  /// d'équipe) + SON poste + SON N° de vol. Ajouter un GDV via le "+" ajoute
  /// donc automatiquement sa propre ligne poste (et vol si applicable), au
  /// lieu d'un unique poste/vol partagé pour toute la session.
  Widget _buildSessionEntryRow(int index, _SessionFieldsConfig cfg) {
    final entry = _sessionEntries[index];
    final numbered = _sessionEntries.length > 1;
    return Padding(
      padding: EdgeInsets.only(bottom: index == _sessionEntries.length - 1 ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: entry.identifiantCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (_) => setState(() {}),
              decoration: _sessionFieldDecoration(
                numbered ? "${cfg.label1} ${index + 1}" : cfg.label1,
                cfg.icon1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: cfg.showNumeroVol ? 2 : 3,
            child: _posteSelectorForEntry(entry, cfg.posteOptions),
          ),
          if (cfg.showNumeroVol) ...[
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: entry.numeroVolCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: _sessionFieldDecoration("N° de vol", Icons.flight),
              ),
            ),
          ],
          if (_sessionEntries.length > 1) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _retirerSessionEntry(index),
              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
              tooltip: "Retirer cette ligne",
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
            ),
          ],
        ],
      ),
    );
  }

  /// Bouton "+" : ajoute une nouvelle ligne complète (identifiant+poste+vol).
  Widget _addSessionEntryButton(String label1) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: _ajouterSessionEntry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, size: 15, color: Colors.purpleAccent),
              const SizedBox(width: 6),
              Text(
                "Ajouter ${label1.toLowerCase()}",
                style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
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
            onPressed: () {
              // Cette évaluation n'a pas encore été persistée en base (elle
              // ne le sera qu'au "TERMINER LA SESSION") : on se contente donc
              // d'un reset purement local. Appeler EmployeeRepository.init()
              // ici remplacerait TOUS les agents par des objets fraîchement
              // rechargés depuis Supabase, qui ne portent pas les indicateurs
              // locaux isValidated/evaluationScore des AUTRES agents encore
              // en attente — ce qui effaçait toute la liste "Évalués" au lieu
              // de n'annuler que cet agent.
              setState(() {
                emp['isValidated'] = false;
                emp['evaluationScore'] = null;
                emp['evaluationSelections'] = null;
                _selectedForCancel.remove(emp['id']);
              });
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
                        for (int i = 0; i < _sessionEntries.length; i++) ...[
                          const SizedBox(height: 8),
                          _infoRow(
                            _fieldsConfig.icon1,
                            _sessionEntries.length > 1 ? "${_fieldsConfig.label1} ${i + 1}" : _fieldsConfig.label1,
                            _sessionEntries[i].identifiantCtrl.text.trim(),
                          ),
                          const SizedBox(height: 8),
                          _infoRow(Icons.meeting_room_outlined, "Poste", _sessionEntries[i].poste ?? '—'),
                          if (_fieldsConfig.showNumeroVol) ...[
                            const SizedBox(height: 8),
                            _infoRow(Icons.flight, "N° de vol", _sessionEntries[i].numeroVolCtrl.text.trim()),
                          ],
                        ],
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
            "Demandez au Rep de débloquer cette date "
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
        // NOTE REPO : `enregistrerEvaluationControlee` doit accepter les
        // nouveaux paramètres nommés `gdv`, `poste` et `numeroVol` et les
        // faire persister dans les colonnes correspondantes de la table
        // `evaluations` (ex : gdv text, poste text, numero_vol text).
        final resultat = await EmployeeRepository.instance.enregistrerEvaluationControlee(
          agentId: emp['id'],
          scoreTotal: emp['evaluationScore'],
          items: items,
          evaluateur: evaluator,
          vacation: _vacationController.text.trim(),
          dateEvaluation: _sessionDate,
          commentaire: estRecalage ? raisonRecalage : null,
          gdv: _gdvCombine,
          poste: _posteCombine,
          numeroVol: _numeroVolCombine.isEmpty ? null : _numeroVolCombine,
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

  /// Ré-ouvre la grille de notation pour un agent déjà évalué DANS CETTE
  /// SESSION (pas encore enregistré en base), pré-remplie avec ses choix
  /// actuels, pour permettre de les amender avant "TERMINER LA SESSION".
  void _editSessionEvaluation(Map<String, dynamic> emp) {
    final currentSelections = emp['evaluationSelections'] != null
        ? List<int?>.from(emp['evaluationSelections'])
        : null;
    showDialog(
      context: context,
      builder: (ctx) => EvaluationDialog(
        employee: emp,
        criteria: _criteria,
        initialSelections: currentSelections,
        onValidate: (selections) {
          double totalScore = 0.0;
          for (int i = 0; i < _criteria.length; i++) {
            if (selections[i] != null) {
              totalScore += _criteria[i]['options'][selections[i]]['score'];
            }
          }
          setState(() {
            emp['evaluationScore'] = totalScore;
            emp['evaluationSelections'] = selections;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _cancelMultipleEvaluations() {
    // Comme pour _showCancelDialog : ces évaluations ne sont pas encore
    // persistées, donc pas d'appel à widget.onUpdate() ici (qui déclenche
    // côté écran parent un rechargement depuis Supabase et effacerait le
    // statut local des agents non concernés par cette suppression).
    for (var emp in _filteredEmployees) {
      if (_selectedForCancel.contains(emp['id'])) {
        emp['isValidated'] = false;
        emp['evaluationScore'] = null;
        emp['evaluationSelections'] = null;
      }
    }
    _selectedForCancel.clear();
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
            "du Rep, ou DEX.",
      );
      return;
    }
    _openEditDialog(evaluation);
  }

  /// Supprime définitivement une évaluation déjà enregistrée en base,
  /// après confirmation et vérification du verrou 48h.
  Future<void> _onTapSupprimerResultat(Map<String, dynamic> evaluation) async {
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
            "Elle ne peut plus être supprimée sans déblocage préalable "
            "du Rep, ou DEX.",
      );
      return;
    }

    final agent = _agentDeEvaluation(evaluation);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 40),
        title: Text(
          "Supprimer l'évaluation de ${agent['nom']} ${agent['prenom']} ?",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: const Text(
          "Cette action est définitive et ne peut pas être annulée.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      // NOTE REPO : nécessite une méthode `supprimerEvaluation({required
      // String evaluationId})` côté EmployeeRepository, qui exécute la
      // suppression correspondante en base (Supabase .delete()).
      await EmployeeRepository.instance.supprimerEvaluation(
        evaluationId: evaluation['id'].toString(),
      );
      await widget.onUpdate();
      await _rechercherEvaluationsAModifier();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Évaluation supprimée'),
            backgroundColor: Colors.redAccent,
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
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _sessionHeaderExpanded = !_sessionHeaderExpanded),
                    icon: Icon(
                      _sessionHeaderExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white54,
                      size: 20,
                    ),
                    tooltip: _sessionHeaderExpanded ? "Réduire la session" : "Développer la session",
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ]),

                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: !_sessionHeaderExpanded
                      ? const SizedBox(height: 4)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                // Une ligne par GDV/Agent/Chef d'équipe, chacune avec SON
                // propre poste et SON propre N° de vol (le "+" ajoute une
                // ligne complète) → composition pilotée par _fieldsConfig
                // selon le profil de superviseur (service ciblé).
                Builder(builder: (context) {
                  final cfg = _fieldsConfig;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _sessionEntries.length; i++)
                        _buildSessionEntryRow(i, cfg),
                      _addSessionEntryButton(cfg.label1),
                    ],
                  );
                }),

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
                          ],
                        ),
                ),
                const SizedBox(height: 10),
                       
                Builder(builder: (context) {
                  final cfg = _fieldsConfig;
                  final entriesResume = _sessionEntries.map((e) {
                    final bits = [
                      e.identifiantCtrl.text.trim(),
                      e.poste ?? '',
                      if (cfg.showNumeroVol) "vol ${e.numeroVolCtrl.text.trim()}",
                    ].where((s) => s.isNotEmpty).join(' · ');
                    return bits;
                  }).where((s) => s.isNotEmpty).join('  |  ');
                  final resume = [
                    _evaluateurController.text.trim(),
                    _vacationController.text.trim(),
                    entriesResume,
                  ].where((s) => s.isNotEmpty).join(' · ');
                  return Row(children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _sessionReady ? Colors.greenAccent : Colors.white24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sessionReady
                            ? "Session prête — $resume"
                            : "Renseignez la vacation, l'évaluateur, ${cfg.label1.toLowerCase()}, le poste"
                                "${cfg.showNumeroVol ? ' et le n° de vol' : ''} pour commencer",
                        style: TextStyle(
                          fontSize: 12,
                          color: _sessionReady ? Colors.white70 : Colors.white38,
                        ),
                      ),
                    ),
                  ]);
                }),
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
    // Hauteur bornée + barre de défilement dédiée (ScrollController propre,
    // pour éviter tout conflit de PrimaryScrollController) : évite tout
    // débordement quand la recherche renvoie beaucoup de résultats.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: Scrollbar(
        controller: _searchResultsScrollCtrl,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _searchResultsScrollCtrl,
          shrinkWrap: true,
          padding: const EdgeInsets.only(right: 4),
          itemCount: _editSearchResults.length,
          itemBuilder: (context, index) {
              final eval = _editSearchResults[index];
              final agent = _agentDeEvaluation(eval);
              final rawDate = eval['date_evaluation'] as String?;
              final vacation = (eval['vacation'] as String?) ?? '';
              // NOTE : le score n'est volontairement PAS affiché ici — les
              // superviseurs évaluent mais ne doivent pas connaître la note
              // (réservée aux reps/DEX dans le classement).

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
                      IconButton(
                        onPressed: () => _onTapResultatModification(eval),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white54),
                        tooltip: "Amender",
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                      IconButton(
                        onPressed: () => _onTapSupprimerResultat(eval),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        tooltip: "Supprimer",
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ],
                  ),
                  // Pas de onTap sur la tuile elle-même : seules les deux
                  // icônes (Amender / Supprimer) sont interactives. Avoir un
                  // onTap sur toute la ligne EN PLUS des IconButton dans
                  // `trailing` créait une ambiguïté de hit-test (double
                  // déclenchement possible au clic) qui provoquait un blocage
                  // de l'interface après une recherche.
                ),
              );
          },
        ),
      ),
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
        if (isDone && _selectedForCancel.isNotEmpty) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: _selectedForCancel.length == 1
                ? Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final matches = list.where((e) => e['id'] == _selectedForCancel.first);
                          if (matches.isNotEmpty) _editSessionEvaluation(matches.first);
                        },
                        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                        label: const Text("Modifier", style: TextStyle(color: Colors.white, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent.withOpacity(0.9),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final matches = list.where((e) => e['id'] == _selectedForCancel.first);
                          if (matches.isNotEmpty) _showCancelDialog(matches.first);
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 15),
                        label: const Text("Supprimer", style: TextStyle(color: Colors.white, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedForCancel.clear()),
                      icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                      tooltip: "Désélectionner",
                    ),
                  ])
                : Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _cancelMultipleEvaluations,
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        label: Text(
                          "Supprimer (${_selectedForCancel.length})",
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedForCancel.clear()),
                      icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                      tooltip: "Désélectionner",
                    ),
                  ]),
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
                  selectedTileColor: Colors.purpleAccent.withOpacity(0.1),
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
                              ? Colors.purpleAccent
                              : (isDone ? Colors.greenAccent : Colors.white24),
                          size: 16,
                        ),
                    ],
                  ),
                  onTap: isExempt
                      ? null
                      : () {
                          if (isDone) {
                            setState(() {
                              if (_isControlDown) {
                                // Ctrl+clic : sélection multiple (pour suppression groupée).
                                if (isSelected) {
                                  _selectedForCancel.remove(emp['id']);
                                } else {
                                  _selectedForCancel.add(emp['id'] as String);
                                }
                              } else if (isSelected && _selectedForCancel.length == 1) {
                                // Clic simple sur l'agent déjà seul sélectionné → désélectionne.
                                _selectedForCancel.clear();
                              } else {
                                // Clic simple : sélection exclusive d'un seul agent
                                // (affiche "Modifier" / "Supprimer" pour lui).
                                _selectedForCancel
                                  ..clear()
                                  ..add(emp['id'] as String);
                              }
                            });
                          } else {
                            if (_selectedForCancel.isNotEmpty) {
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