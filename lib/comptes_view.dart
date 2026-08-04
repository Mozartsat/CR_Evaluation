import 'package:flutter/material.dart';
import 'auth_manager.dart';

const List<String> _kRoles = ['admin', 'dex', 'rep', 'sup'];
const List<String> _kVilles = ['PNR', 'BZV', 'ALL'];
const List<String> _kServices = ['Passage', 'Ops', 'Piste', 'Fret', 'Garage'];

Color _couleurRole(String role) {
  switch (role) {
    case 'admin':
      return Colors.purpleAccent;
    case 'dex':
      return Colors.amber;
    case 'rep':
      return Colors.blueAccent;
    case 'sup':
      return Colors.tealAccent;
    default:
      return Colors.white54;
  }
}

class ComptesView extends StatefulWidget {
  const ComptesView({super.key});

  @override
  State<ComptesView> createState() => _ComptesViewState();
}

class _ComptesViewState extends State<ComptesView> {
  List<Map<String, dynamic>> _comptes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _isLoading = true);
    try {
      final comptes = await AuthManager.listerComptes();
      if (mounted) setState(() => _comptes = comptes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtres = _comptes.where((c) {
      if (_searchQuery.isEmpty) return true;
      return (c['identifiant'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList()
      ..sort((a, b) => (a['identifiant'] ?? '').toString().compareTo((b['identifiant'] ?? '').toString()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un identifiant…',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: Colors.white24, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => _ouvrirFormulaireCompte(),
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text("Ajouter un compte"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _charger,
              icon: const Icon(Icons.refresh, color: Colors.white38),
              tooltip: "Actualiser",
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
              : filtres.isEmpty
                  ? const Center(
                      child: Text("Aucun compte trouvé", style: TextStyle(color: Colors.white38)),
                    )
                  : ListView.separated(
                      itemCount: filtres.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildCompteTile(filtres[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildCompteTile(Map<String, dynamic> compte) {
    final String identifiant = (compte['identifiant'] ?? '').toString();
    final String role = (compte['role'] ?? '').toString();
    final String ville = (compte['ville'] ?? '').toString();
    final List<String> services = List<String>.from((compte['services'] as List?) ?? const []);
    final bool actif = compte['actif'] != false;
    final bool bloque = compte['bloque'] == true;
    final String? dernierLogin = compte['dernier_login']?.toString();
    final String compteId = compte['id'].toString();
    final bool estMoi = identifiant == AuthManager.currentUserID;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16122D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _couleurRole(role).withOpacity(0.15),
            child: Text(
              identifiant.isNotEmpty ? identifiant[0].toUpperCase() : '?',
              style: TextStyle(color: _couleurRole(role), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      identifiant,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (estMoi) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("vous", style: TextStyle(color: Colors.purpleAccent, fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _badge(role.toUpperCase(), _couleurRole(role)),
                    _badge(ville, Colors.white54),
                    if (services.isNotEmpty)
                      ...services.map((s) => _badge(s, Colors.white38)),
                    if (bloque)
                      _badge("BLOQUÉ", Colors.redAccent)
                    else if (!actif)
                      _badge("DÉSACTIVÉ", Colors.orangeAccent)
                    else
                      _badge("ACTIF", Colors.greenAccent),
                  ],
                ),
                if (dernierLogin != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Dernière connexion : ${_formatDate(dernierLogin)}",
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          Wrap(
            spacing: 2,
            children: [
              IconButton(
                onPressed: () => _ouvrirFormulaireCompte(compte: compte),
                icon: const Icon(Icons.edit_outlined, size: 17, color: Colors.white54),
                tooltip: "Modifier les droits",
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                onPressed: () => _ouvrirChangementMotDePasse(compteId, identifiant),
                icon: const Icon(Icons.key_outlined, size: 17, color: Colors.white54),
                tooltip: "Changer le mot de passe",
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                onPressed: estMoi ? null : () => _toggleBlocage(compteId, identifiant, !bloque),
                icon: Icon(
                  bloque ? Icons.lock_open_outlined : Icons.lock_outline,
                  size: 17,
                  color: estMoi ? Colors.white12 : (bloque ? Colors.greenAccent : Colors.orangeAccent),
                ),
                tooltip: bloque ? "Débloquer" : "Bloquer",
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                onPressed: estMoi ? null : () => _toggleActivation(compteId, identifiant, !actif),
                icon: Icon(
                  actif ? Icons.toggle_on : Icons.toggle_off_outlined,
                  size: 19,
                  color: estMoi ? Colors.white12 : (actif ? Colors.greenAccent : Colors.white38),
                ),
                tooltip: actif ? "Désactiver" : "Activer",
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                onPressed: estMoi ? null : () => _supprimerCompte(compteId, identifiant),
                icon: Icon(Icons.delete_outline, size: 17, color: estMoi ? Colors.white12 : Colors.redAccent),
                tooltip: "Supprimer",
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} "
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _toggleBlocage(String compteId, String identifiant, bool bloque) async {
    try {
      await AuthManager.definirBlocage(
        compteId: compteId,
        identifiantPourJournal: identifiant,
        bloque: bloque,
      );
      await _charger();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _toggleActivation(String compteId, String identifiant, bool actif) async {
    try {
      await AuthManager.definirActivation(
        compteId: compteId,
        identifiantPourJournal: identifiant,
        actif: actif,
      );
      await _charger();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _supprimerCompte(String compteId, String identifiant) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16122D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 40),
        title: Text(
          "Supprimer le compte $identifiant ?",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: const Text(
          "Cette action est définitive.",
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
      await AuthManager.supprimerCompte(compteId: compteId, identifiantPourJournal: identifiant);
      await _charger();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _ouvrirChangementMotDePasse(String compteId, String identifiant) {
    final nouveauCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    String? erreur;
    bool enCours = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> valider() async {
            if (nouveauCtrl.text.trim().isEmpty) {
              setModalState(() => erreur = "Le mot de passe ne peut pas être vide.");
              return;
            }
            if (nouveauCtrl.text != confirmCtrl.text) {
              setModalState(() => erreur = "Les deux mots de passe ne correspondent pas.");
              return;
            }
            setModalState(() {
              enCours = true;
              erreur = null;
            });
            final ok = await AuthManager.adminChangerMotDePasse(
              compteId: compteId,
              nouveauMotDePasse: nouveauCtrl.text,
            );
            if (!ctx.mounted) return;
            if (ok) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Mot de passe de $identifiant modifié.'), backgroundColor: Colors.green),
              );
            } else {
              setModalState(() {
                enCours = false;
                erreur = "Erreur lors du changement de mot de passe.";
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF16122D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text("Mot de passe de $identifiant", style: const TextStyle(color: Colors.white, fontSize: 15)),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nouveauCtrl,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Nouveau mot de passe",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white38, size: 18),
                        onPressed: () => setModalState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Confirmer",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => valider(),
                  ),
                  if (erreur != null) ...[
                    const SizedBox(height: 10),
                    Text(erreur!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: enCours ? null : () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: enCours ? null : valider,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                child: enCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("VALIDER"),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Formulaire unique pour créer un compte (compte == null) ou modifier
  /// les droits d'un compte existant (identifiant non modifiable une fois
  /// créé — c'est la clé de connexion).
  void _ouvrirFormulaireCompte({Map<String, dynamic>? compte}) {
    final estCreation = compte == null;
    final identifiantCtrl = TextEditingController(text: compte?['identifiant']?.toString() ?? '');
    final motDePasseCtrl = TextEditingController();
    String role = compte?['role']?.toString() ?? 'sup';
    String ville = compte?['ville']?.toString() ?? 'PNR';
    final Set<String> services = Set<String>.from((compte?['services'] as List?) ?? const []);
    String? erreur;
    bool enCours = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> valider() async {
            if (identifiantCtrl.text.trim().isEmpty) {
              setModalState(() => erreur = "L'identifiant est obligatoire.");
              return;
            }
            if (estCreation && motDePasseCtrl.text.trim().isEmpty) {
              setModalState(() => erreur = "Le mot de passe initial est obligatoire.");
              return;
            }
            setModalState(() {
              enCours = true;
              erreur = null;
            });
            try {
              if (estCreation) {
                await AuthManager.ajouterCompte(
                  identifiant: identifiantCtrl.text.trim(),
                  motDePasse: motDePasseCtrl.text,
                  role: role,
                  ville: ville,
                  services: services.toList(),
                );
              } else {
                await AuthManager.modifierDroitsCompte(
                  compteId: compte['id'].toString(),
                  identifiantPourJournal: identifiantCtrl.text.trim(),
                  role: role,
                  ville: ville,
                  services: services.toList(),
                );
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await _charger();
            } catch (e) {
              setModalState(() {
                enCours = false;
                erreur = "$e";
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF16122D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              estCreation ? "Ajouter un compte" : "Modifier les droits — ${compte['identifiant']}",
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: identifiantCtrl,
                    enabled: estCreation,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Identifiant",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  if (estCreation) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: motDePasseCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Mot de passe initial",
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text("Rôle", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _kRoles.map((r) {
                      final selected = role == r;
                      return ChoiceChip(
                        label: Text(r.toUpperCase()),
                        selected: selected,
                        onSelected: (_) => setModalState(() => role = r),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        selectedColor: _couleurRole(r).withOpacity(0.25),
                        labelStyle: TextStyle(
                          color: selected ? _couleurRole(r) : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: selected ? _couleurRole(r) : Colors.white12),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text("Ville", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _kVilles.map((v) {
                      final selected = ville == v;
                      return ChoiceChip(
                        label: Text(v == 'ALL' ? 'Les deux' : v),
                        selected: selected,
                        onSelected: (_) => setModalState(() => ville = v),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        selectedColor: Colors.purpleAccent.withOpacity(0.25),
                        labelStyle: TextStyle(
                          color: selected ? Colors.purpleAccent : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: selected ? Colors.purpleAccent : Colors.white12),
                        ),
                      );
                    }).toList(),
                  ),
                  if (role == 'rep' || role == 'sup') ...[
                    const SizedBox(height: 14),
                    const Text("Services (rep/sup uniquement)", style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _kServices.map((s) {
                        final selected = services.contains(s);
                        return FilterChip(
                          label: Text(s),
                          selected: selected,
                          onSelected: (v) => setModalState(() {
                            if (v) {
                              services.add(s);
                            } else {
                              services.remove(s);
                            }
                          }),
                          backgroundColor: Colors.white.withOpacity(0.05),
                          selectedColor: Colors.tealAccent.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: selected ? Colors.tealAccent : Colors.white54,
                            fontSize: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: selected ? Colors.tealAccent : Colors.white12),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (erreur != null) ...[
                    const SizedBox(height: 12),
                    Text(erreur!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: enCours ? null : () => Navigator.pop(ctx),
                child: const Text("Annuler", style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: enCours ? null : valider,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                child: enCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(estCreation ? "CRÉER" : "ENREGISTRER"),
              ),
            ],
          );
        },
      ),
    );
  }
}