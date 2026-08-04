import 'package:flutter/material.dart';
import 'employee_repository.dart';

/// Écran "Journal d'activité" — réservé à l'admin (branché depuis
/// main.dart). Liste chronologique de toutes les actions de mutation
/// journalisées par EmployeeRepository (voir _journaliser), avec filtres
/// par compte / type d'action / ville / période.
class JournalActiviteView extends StatefulWidget {
  const JournalActiviteView({super.key});

  @override
  State<JournalActiviteView> createState() => _JournalActiviteViewState();
}

class _JournalActiviteViewState extends State<JournalActiviteView> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _entries = [];

  final _compteCtrl = TextEditingController();
  String _actionFiltre = 'Tous';
  String _villeFiltre = 'Tous';
  DateTime? _dateDebut;
  DateTime? _dateFin;

  static const List<String> _actions = [
    'Tous',
    'creation',
    'modification',
    'suppression',
    'deblocage',
    'blocage',
    'connexion',
    'deconnexion',
    'quota_atteint',
  ];

  static const Map<String, String> _actionLabels = {
    'creation': 'Création',
    'modification': 'Modification',
    'suppression': 'Suppression',
    'deblocage': 'Déblocage',
    'blocage': 'Blocage',
    'connexion': 'Connexion',
    'deconnexion': 'Déconnexion',
    'quota_atteint': 'Quota atteint',
  };

  static const Map<String, IconData> _actionIcons = {
    'creation': Icons.add_circle_outline,
    'modification': Icons.edit_outlined,
    'suppression': Icons.delete_outline,
    'deblocage': Icons.lock_open_outlined,
    'blocage': Icons.lock_outline,
    'connexion': Icons.login,
    'deconnexion': Icons.logout,
    'quota_atteint': Icons.block_outlined,
  };

  static const Map<String, Color> _actionColors = {
    'creation': Colors.greenAccent,
    'modification': Colors.orangeAccent,
    'suppression': Colors.redAccent,
    'deblocage': Colors.purpleAccent,
    'blocage': Colors.blueGrey,
    'connexion': Colors.cyanAccent,
    'deconnexion': Colors.white38,
    'quota_atteint': Colors.amber,
  };

  static const Map<String, String> _cibleLabels = {
    'agent': 'Agent',
    'evaluation': 'Évaluation',
    'deblocage': 'Déblocage',
    'quota': 'Quota',
    'session': 'Session',
    'reset_service': 'Réinitialisation service',
    'compte': 'Compte',
  };

  @override
  void initState() {
    super.initState();
    _rechercher();
  }

  @override
  void dispose() {
    _compteCtrl.dispose();
    super.dispose();
  }

  Future<void> _rechercher() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await EmployeeRepository.instance.rechercherJournal(
        compte: _compteCtrl.text.trim().isEmpty ? null : _compteCtrl.text.trim(),
        action: _actionFiltre == 'Tous' ? null : _actionFiltre,
        ville: _villeFiltre == 'Tous' ? null : _villeFiltre,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      if (!mounted) return;
      setState(() {
        _entries = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _effacerFiltres() {
    setState(() {
      _compteCtrl.clear();
      _actionFiltre = 'Tous';
      _villeFiltre = 'Tous';
      _dateDebut = null;
      _dateFin = null;
    });
    _rechercher();
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    final local = d.toLocal();
    final date =
        "${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}";
    final time =
        "${local.hour.toString().padLeft(2, '0')}h${local.minute.toString().padLeft(2, '0')}";
    return "$date · $time";
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      prefixIcon: Icon(icon, color: Colors.white38, size: 16),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFiltres(),
        const SizedBox(height: 16),
        Expanded(child: _buildListe()),
      ],
    );
  }

  Widget _buildFiltres() {
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
            const Icon(Icons.receipt_long_outlined, size: 16, color: Colors.purpleAccent),
            const SizedBox(width: 8),
            const Text(
              "Journal d'activité",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
              child: Text("${_entries.length} évènement(s)",
                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _compteCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _fieldDecoration("Compte (ex: KAK, DEO...)", Icons.person_search),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _actionFiltre,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF16122D),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    iconEnabledColor: Colors.white38,
                    items: _actions
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text(a == 'Tous' ? 'Toute action' : (_actionLabels[a] ?? a)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _actionFiltre = v ?? 'Tous'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _villeFiltre,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF16122D),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    iconEnabledColor: Colors.white38,
                    items: ['Tous', 'PNR', 'BZV']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v == 'Tous' ? 'Toute ville' : v)))
                        .toList(),
                    onChanged: (v) => setState(() => _villeFiltre = v ?? 'Tous'),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildDateField("Du (optionnel)", _dateDebut, (d) => setState(() => _dateDebut = d))),
            const SizedBox(width: 10),
            Expanded(child: _buildDateField("Au (optionnel)", _dateFin, (d) => setState(() => _dateFin = d))),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _rechercher,
              icon: _isLoading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.search, size: 16, color: Colors.black),
              label: const Text("Chercher", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _effacerFiltres,
              icon: const Icon(Icons.close, size: 18, color: Colors.white38),
              tooltip: "Effacer les filtres",
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? value, void Function(DateTime?) onPicked) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2023),
          lastDate: DateTime.now().add(const Duration(days: 1)),
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
        if (d != null) onPicked(d);
      },
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(
            text: value == null
                ? ''
                : "${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}",
          ),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _fieldDecoration(label, Icons.calendar_today),
        ),
      ),
    );
  }

  Widget _buildListe() {
    if (_error != null) {
      return Center(
        child: Text("Erreur : $_error", style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (_isLoading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text("Aucun évènement pour ces critères.", style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (c, i) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _buildEntryTile(_entries[index]),
    );
  }

  Widget _buildEntryTile(Map<String, dynamic> entry) {
    final action = (entry['action'] ?? '').toString();
    final color = _actionColors[action] ?? Colors.white38;
    final icon = _actionIcons[action] ?? Icons.info_outline;
    final cibleType = (entry['cible_type'] ?? '').toString();
    final cibleLabel = _cibleLabels[cibleType] ?? cibleType;
    final cibleLibelle = (entry['cible_libelle'] ?? '').toString();
    final compte = (entry['compte'] ?? '—').toString();
    final role = (entry['role'] ?? '').toString();
    final ville = (entry['ville'] ?? '').toString();
    final service = (entry['service'] ?? '').toString();
    final details = entry['details'];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16122D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white24,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
        title: Row(children: [
          Text(
            _actionLabels[action] ?? action,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cibleLibelle.trim().isNotEmpty ? "$cibleLabel · $cibleLibelle" : cibleLabel,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            [
              _formatDateTime(entry['cree_le']?.toString()),
              "par $compte${role.isNotEmpty ? ' ($role)' : ''}",
              if (ville.isNotEmpty) ville,
              if (service.isNotEmpty) service,
            ].join(' · '),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ),
        children: [
          if (details is Map && details.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: details.entries.map((e) {
                  final v = e.value;
                  if (v == null || v.toString().trim().isEmpty) return const SizedBox.shrink();
                  return Text(
                    "${e.key} : $v",
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  );
                }).toList(),
              ),
            )
          else
            const Text("Aucun détail supplémentaire.", style: TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }
}