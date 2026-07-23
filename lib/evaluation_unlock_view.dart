import 'package:flutter/material.dart';
import 'employee_repository.dart';

/// Écran de recherche + déblocage d'évaluations.
/// Utilisé par :
/// - Rep / Admin depuis main.dart (service déjà fixé par la navigation)
/// - DEX depuis director_view.dart (service au choix, via [allowServicePicker])
class EvaluationUnlockView extends StatefulWidget {
  final String ville;
  final String? initialService;
  final bool allowServicePicker;
  final String debloquePar;
  // Suppression de sessions complètes réservée à Rep/Admin (pas DEX par défaut).
  final bool canDeleteSessions;

  const EvaluationUnlockView({
    super.key,
    required this.ville,
    this.initialService,
    this.allowServicePicker = false,
    required this.debloquePar,
    this.canDeleteSessions = false,
  });

  @override
  State<EvaluationUnlockView> createState() => _EvaluationUnlockViewState();
}

class _EvaluationUnlockViewState extends State<EvaluationUnlockView> {
  static const List<String> _services = [
    'Passage',
    'Ops',
    'Piste',
    'Fret',
    'Garage',
  ];

  late String _selectedService;
  DateTime? _searchDate;
  final _vacationCtrl = TextEditingController();
  final _evaluateurCtrl = TextEditingController();

  bool _isSearching = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _results = [];

  List<Map<String, dynamic>> _deblocagesActifs = [];

  // --- Recherche / suppression de sessions complètes (Rep/Admin) ---
  DateTime? _sessionSearchDate;
  final _sessionEvaluateurCtrl = TextEditingController();
  bool _isSearchingSessions = false;
  bool _hasSearchedSessions = false;
  List<Map<String, dynamic>> _sessionResults = [];

  // --- Quota mensuel de jours d'évaluation (DEX / Rep / Admin) ---
  final _quotaCtrl = TextEditingController();
  Map<String, dynamic>? _quotaActuel;
  bool _isLoadingQuota = true;
  bool _isSavingQuota = false;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService ?? _services.first;
    _chargerDeblocagesActifs();
    _chargerQuota();
  }

  @override
  void dispose() {
    _vacationCtrl.dispose();
    _evaluateurCtrl.dispose();
    _sessionEvaluateurCtrl.dispose();
    _quotaCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerQuota() async {
    setState(() => _isLoadingQuota = true);
    final row = await EmployeeRepository.instance.getParametreQuota();
    if (mounted) {
      setState(() {
        _quotaActuel = row;
        _quotaCtrl.text = row == null ? '' : row['valeur'].toString();
        _isLoadingQuota = false;
      });
    }
  }

  Future<void> _enregistrerQuota() async {
    final valeur = int.tryParse(_quotaCtrl.text.trim());
    if (valeur == null || valeur <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrez un nombre de jours valide (> 0).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _isSavingQuota = true);
    try {
      await EmployeeRepository.instance.setMaxJoursEvaluation(
        valeur,
        widget.debloquePar,
      );
      await _chargerQuota();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quota fixé à $valeur jour(s) d\'évaluation par mois et par agent.'),
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
    } finally {
      if (mounted) setState(() => _isSavingQuota = false);
    }
  }

  Future<void> _supprimerQuota() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Repasser en illimité ?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Plus aucune limite de jours d'évaluation par agent ne sera appliquée.",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await EmployeeRepository.instance.supprimerQuota();
      await _chargerQuota();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildQuotaPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.tune, size: 16, color: Colors.purpleAccent),
            SizedBox(width: 8),
            Text(
              "Quota mensuel de jours d'évaluation",
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Nombre maximum de jours distincts où un même agent peut être "
            "évalué, par mois. Au-delà, les nouvelles évaluations sont "
            "automatiquement ignorées.",
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (_isLoadingQuota)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
            )
          else
            Row(children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _quotaCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _fieldDecoration("Jours autorisés", Icons.event_available),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isSavingQuota ? null : _enregistrerQuota,
                icon: _isSavingQuota
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text("Enregistrer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(width: 10),
              if (_quotaActuel != null)
                TextButton.icon(
                  onPressed: _supprimerQuota,
                  icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.white54),
                  label: const Text("Repasser en illimité", style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
            ]),
          if (_quotaActuel != null) ...[
            const SizedBox(height: 8),
            Text(
              "Actuellement : ${_quotaActuel!['valeur']} jour(s)/mois — "
              "dernière modification par ${_quotaActuel!['modifie_par'] ?? '—'}",
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Aucun quota configuré actuellement : illimité.",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  bool _estAncienneDe48h(DateTime? date) {
    if (date == null) return false;
    final debut = DateTime(date.year, date.month, date.day);
    return DateTime.now().difference(debut).inHours > 48;
  }

  /// Cherche, parmi les déblocages actifs déjà chargés, celui qui couvre
  /// la date/vacation donnée (vacation vide dans le déblocage = toute la
  /// journée, donc couvre n'importe quelle vacation).
  Map<String, dynamic>? _findActiveDeblocageFor(DateTime? date, String vacation) {
    if (date == null) return null;
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    for (final d in _deblocagesActifs) {
      final dCible = (d['date_cible'] as String?) ?? '';
      if (!dCible.startsWith(dateStr)) continue;
      final dVac = (d['vacation'] as String?) ?? '';
      if (dVac.isEmpty || dVac == vacation) return d;
    }
    return null;
  }

  Future<void> _chargerDeblocagesActifs() async {
    final list = await EmployeeRepository.instance.listerDeblocagesActifs(
      ville: widget.ville,
      service: _selectedService,
    );
    if (mounted) setState(() => _deblocagesActifs = list);
  }

  Future<void> _rechercher() async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });
    try {
      final results = await EmployeeRepository.instance.rechercherEvaluations(
        ville: widget.ville,
        service: _selectedService,
        vacation: _vacationCtrl.text.trim(),
        evaluateur: _evaluateurCtrl.text.trim(),
        date: _searchDate,
      );
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche : $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _effacerRechercheEvaluation() {
    setState(() {
      _searchDate = null;
      _vacationCtrl.clear();
      _evaluateurCtrl.clear();
      _hasSearched = false;
      _results = [];
    });
  }

  Map<String, dynamic> _agentDe(Map<String, dynamic> evaluation) {
    final raw = evaluation['agents'];
    if (raw is List && raw.isNotEmpty) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {'nom': '—', 'prenom': ''};
  }

  Future<void> _confirmerDeblocage({
    required DateTime dateCible,
    String? vacation,
  }) async {
    final vacationLabel = (vacation == null || vacation.isEmpty)
        ? "toutes vacations de la journée"
        : "vacation « $vacation »";
    final dateLabel =
        "${dateCible.day.toString().padLeft(2, '0')}/${dateCible.month.toString().padLeft(2, '0')}/${dateCible.year}";

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.lock_open, color: Colors.orangeAccent, size: 40),
        title: const Text(
          "Confirmer le déblocage",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Autoriser $_selectedService à ${widget.ville} pour le $dateLabel "
          "($vacationLabel) pendant 24h ?\n\nLe superviseur pourra alors créer ou "
          "modifier une évaluation pour cette date.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text("Débloquer"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await EmployeeRepository.instance.creerDeblocage(
        ville: widget.ville,
        service: _selectedService,
        dateCible: dateCible,
        vacation: vacation,
        debloquePar: widget.debloquePar,
      );
      await _chargerDeblocagesActifs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Déblocage accordé pour 24h.'), backgroundColor: Colors.green),
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

  Future<void> _bloquerDeblocage(Map<String, dynamic> deblocage) async {
    final vacation = (deblocage['vacation'] as String?) ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.lock, color: Colors.redAccent, size: 40),
        title: const Text(
          "Bloquer cette évaluation ?",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Le déblocage du ${deblocage['date_cible']} "
          "(${vacation.isEmpty ? 'toute la journée' : vacation}) sera annulé "
          "immédiatement. Le superviseur ne pourra plus créer ni modifier "
          "d'évaluation pour cette date tant qu'un nouveau déblocage n'aura "
          "pas été accordé.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Bloquer"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await EmployeeRepository.instance.annulerDeblocage(deblocage['id'].toString());
      await _chargerDeblocagesActifs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Évaluation rebloquée.'), backgroundColor: Colors.green),
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

  Future<void> _rechercherSessions() async {
    setState(() {
      _isSearchingSessions = true;
      _hasSearchedSessions = true;
    });
    try {
      final results = await EmployeeRepository.instance.rechercherSessionsEvaluation(
        ville: widget.ville,
        service: _selectedService,
        date: _sessionSearchDate,
        evaluateur: _sessionEvaluateurCtrl.text.trim(),
      );
      if (mounted) setState(() => _sessionResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche : $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingSessions = false);
    }
  }

  Future<void> _confirmerSuppressionSession(Map<String, dynamic> session) async {
    final ids = List<String>.from(session['evaluation_ids'] as List);
    final agents = List<Map<String, dynamic>>.from(session['agents'] as List);
    final vacation = (session['vacation'] as String?) ?? '';
    final evaluateur = (session['evaluateur'] as String?) ?? '';
    final date = (session['date_evaluation'] as String?) ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 40),
        title: const Text(
          "Supprimer cette session ?",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Cette action est irréversible.\n\n"
          "$date · ${vacation.isEmpty ? 'toute la journée' : vacation} · "
          "évaluateur : $evaluateur\n\n"
          "${ids.length} évaluation(s) seront supprimées définitivement "
          "(${agents.map((a) => '${a['nom']} ${a['prenom']}').join(', ')}).",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
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

    if (confirmed != true) return;

    try {
      await EmployeeRepository.instance.supprimerSessionEvaluation(ids);
      await _rechercherSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session supprimée.'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    final colonneDeblocage = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntro(),
          const SizedBox(height: 20),
          _buildSearchForm(),
          const SizedBox(height: 20),
          _buildResults(),
          const SizedBox(height: 20),
          _buildDeblocageManuel(),
          const SizedBox(height: 20),
          if (_deblocagesActifs.isNotEmpty) ...[
            _buildDeblocagesActifsSection(),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuotaPanel(),
        const SizedBox(height: 20),
        Expanded(
          child: widget.canDeleteSessions
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: colonneDeblocage),
                    const SizedBox(width: 20),
                    Container(width: 1, color: Colors.white10),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSessionSearchForm(),
                            const SizedBox(height: 20),
                            _buildSessionResults(),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : colonneDeblocage,
        ),
      ],
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        const Icon(Icons.lock_open_outlined, color: Colors.orangeAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "Passé 48h, un superviseur ne peut plus créer une évaluation antidatée "
            "ni modifier une évaluation existante sans votre déblocage.",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  Widget _buildSearchForm() {
    return Container(
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
            const Icon(Icons.search, size: 16, color: Colors.purpleAccent),
            const SizedBox(width: 8),
            const Text(
              "Rechercher une évaluation",
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ]),
          const SizedBox(height: 12),
          if (widget.allowServicePicker) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedService,
                  dropdownColor: const Color(0xFF16122D),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _services
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedService = v);
                    _chargerDeblocagesActifs();
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Chaque champ sur sa propre ligne pour rester lisible, même
          // dans un panneau étroit (accès Rep/Superviseur).
          GestureDetector(
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
              if (d != null) setState(() => _searchDate = d);
            },
            child: AbsorbPointer(
              child: TextField(
                controller: TextEditingController(
                  text: _searchDate == null
                      ? ''
                      : "${_searchDate!.day.toString().padLeft(2, '0')}/${_searchDate!.month.toString().padLeft(2, '0')}/${_searchDate!.year}",
                ),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _fieldDecoration("Date (optionnel)", Icons.calendar_today),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _vacationCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _fieldDecoration("Vacation", Icons.schedule),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _evaluateurCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _fieldDecoration("Évaluateur", Icons.person_outline),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : _rechercher,
                icon: _isSearching
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.search, size: 16, color: Colors.black),
                label: const Text("Chercher", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _effacerRechercheEvaluation,
              icon: const Icon(Icons.close, size: 18, color: Colors.white38),
              tooltip: "Effacer la recherche",
            ),
          ]),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
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

  Widget _buildDeblocageManuel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.add_moderator_outlined, color: Colors.orangeAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _searchDate == null
                ? "Choisissez une date ci-dessus pour pouvoir débloquer une session future/antérieure, avec ou sans évaluation existante."
                : "Débloquer $_selectedService pour le "
                  "${_searchDate!.day.toString().padLeft(2, '0')}/${_searchDate!.month.toString().padLeft(2, '0')}/${_searchDate!.year}"
                  "${_vacationCtrl.text.trim().isEmpty ? ' (toute la journée)' : ' — vacation « ${_vacationCtrl.text.trim()} »'}",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _searchDate == null
              ? null
              : () => _confirmerDeblocage(
                    dateCible: _searchDate!,
                    vacation: _vacationCtrl.text.trim().isEmpty
                        ? null
                        : _vacationCtrl.text.trim(),
                  ),
          icon: const Icon(Icons.lock_open, size: 14, color: Colors.black),
          label: const Text("Débloquer"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white12,
          ),
        ),
      ]),
    );
  }

  Widget _buildDeblocagesActifsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.verified_user_outlined, size: 16, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text(
              "Déblocages actifs (24h)",
              style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ]),
          const SizedBox(height: 8),
          ..._deblocagesActifs.map((d) {
            final vacation = (d['vacation'] as String?) ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "• ${d['date_cible']} · ${vacation.isEmpty ? 'toute la journée' : vacation} "
                      "— débloqué par ${d['debloque_par']}",
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _bloquerDeblocage(d),
                    icon: const Icon(Icons.lock, size: 18, color: Colors.redAccent),
                    tooltip: "Bloquer (annuler le déblocage)",
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (!_hasSearched) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            "Lancez une recherche pour voir les évaluations correspondantes.",
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            "Aucune évaluation trouvée pour ces critères.",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${_results.length} résultat(s)",
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 10),
        ..._results.map((eval) {
          final agent = _agentDe(eval);
          final rawDate = eval['date_evaluation'] as String?;
          final date = rawDate != null ? DateTime.tryParse(rawDate) : null;
          final locked = _estAncienneDe48h(date);
          final vacation = (eval['vacation'] as String?) ?? '';
          final score = (eval['score'] ?? 0.0) as num;
          // Un déblocage actif rend l'évaluation modifiable même si elle a
          // plus de 48h ; on garde alors un cadenas rouge cliquable pour
          // permettre de reverrouiller (undo) sans repasser par la
          // recherche.
          final activeDeblocage = locked ? _findActiveDeblocageFor(date, vacation) : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF16122D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: locked ? Colors.redAccent.withOpacity(0.3) : Colors.white10,
              ),
            ),
            child: Row(children: [
              Icon(
                locked ? Icons.lock_outline : Icons.lock_open_outlined,
                size: 16,
                color: locked ? Colors.redAccent : Colors.greenAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${agent['nom'] ?? ''} ${agent['prenom'] ?? ''}",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      "${rawDate ?? '—'} · ${vacation.isEmpty ? 'vacation non renseignée' : vacation} · "
                      "évaluateur : ${eval['evaluateur'] ?? '—'}",
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                "${score.toStringAsFixed(1)} pts",
                style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 12),
              if (locked && activeDeblocage == null)
                ElevatedButton.icon(
                  onPressed: date == null
                      ? null
                      : () => _confirmerDeblocage(
                            dateCible: date,
                            vacation: vacation.isEmpty ? null : vacation,
                          ),
                  icon: const Icon(Icons.lock_open, size: 14, color: Colors.black),
                  label: const Text("Débloquer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                )
              else if (locked && activeDeblocage != null)
                IconButton(
                  onPressed: () => _bloquerDeblocage(activeDeblocage),
                  icon: const Icon(Icons.lock, color: Colors.redAccent, size: 20),
                  tooltip: "Déjà débloqué — cliquer pour reverrouiller",
                  splashRadius: 20,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Modifiable",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                  ),
                ),
            ]),
          );
        }),
      ],
    );
  }

  Widget _buildSessionSearchForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              "Sessions d'évaluation — recherche & suppression",
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Une session regroupe toutes les évaluations d'une même date, "
            "vacation et évaluateur. Recherchez par date pour voir toutes "
            "les sessions de ce jour, ou par évaluateur pour lister toutes "
            "ses sessions.",
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(children: [
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
                  if (d != null) setState(() => _sessionSearchDate = d);
                },
                child: AbsorbPointer(
                  child: TextField(
                    controller: TextEditingController(
                      text: _sessionSearchDate == null
                          ? ''
                          : "${_sessionSearchDate!.day.toString().padLeft(2, '0')}/${_sessionSearchDate!.month.toString().padLeft(2, '0')}/${_sessionSearchDate!.year}",
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _fieldDecoration("Date (optionnel)", Icons.calendar_today),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _sessionEvaluateurCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _fieldDecoration("Évaluateur (optionnel)", Icons.person_outline),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _isSearchingSessions ? null : _rechercherSessions,
              icon: _isSearchingSessions
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search, size: 16),
              label: const Text("Chercher"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _effacerRechercheSessions,
              icon: const Icon(Icons.close, size: 18, color: Colors.white38),
              tooltip: "Effacer la recherche",
            ),
          ]),
        ],
      ),
    );
  }

  void _effacerRechercheSessions() {
    setState(() {
      _sessionSearchDate = null;
      _sessionEvaluateurCtrl.clear();
      _hasSearchedSessions = false;
      _sessionResults = [];
    });
  }

  Widget _buildSessionResults() {
    if (!_hasSearchedSessions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            "Renseignez une date et/ou un évaluateur pour retrouver des sessions.",
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ),
      );
    }
    if (_sessionResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            "Aucune session trouvée pour ces critères.",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${_sessionResults.length} session(s)",
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 10),
        ..._sessionResults.map((session) {
          final vacation = (session['vacation'] as String?) ?? '';
          final evaluateur = (session['evaluateur'] as String?) ?? '';
          final date = (session['date_evaluation'] as String?) ?? '—';
          final agents = List<Map<String, dynamic>>.from(session['agents'] as List);
          final ids = List<String>.from(session['evaluation_ids'] as List);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF16122D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.folder_shared_outlined, size: 18, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$date · ${vacation.isEmpty ? 'toute la journée' : vacation}",
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        "Évaluateur : ${evaluateur.isEmpty ? '—' : evaluateur} · ${ids.length} agent(s)",
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: agents.map((a) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${a['nom'] ?? ''} ${a['prenom'] ?? ''}",
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _confirmerSuppressionSession(session),
                  icon: const Icon(Icons.delete_forever, size: 14),
                  label: const Text("Supprimer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}