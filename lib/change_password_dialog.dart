import 'package:flutter/material.dart';
import 'auth_manager.dart';

/// Ouvre un dialogue permettant au compte CONNECTÉ de changer SON PROPRE
/// mot de passe (ancien mot de passe requis pour confirmation). Réutilisé
/// depuis main.dart (profil utilisateur) et director_view.dart (sidebar DEX).
void showChangePasswordDialog(BuildContext context) {
  final ancienCtrl = TextEditingController();
  final nouveauCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  bool obscureAncien = true;
  bool obscureNouveau = true;
  String? erreur;
  bool enCours = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        Future<void> valider() async {
          final ancien = ancienCtrl.text;
          final nouveau = nouveauCtrl.text;
          final confirm = confirmCtrl.text;

          if (nouveau.trim().isEmpty) {
            setModalState(() => erreur = "Le nouveau mot de passe ne peut pas être vide.");
            return;
          }
          if (nouveau != confirm) {
            setModalState(() => erreur = "Les deux mots de passe ne correspondent pas.");
            return;
          }
          setModalState(() {
            enCours = true;
            erreur = null;
          });
          final ok = await AuthManager.changerMonMotDePasse(
            ancienMotDePasse: ancien,
            nouveauMotDePasse: nouveau,
          );
          if (!ctx.mounted) return;
          if (ok) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Mot de passe modifié avec succès."),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            setModalState(() {
              enCours = false;
              erreur = "Ancien mot de passe incorrect, ou erreur réseau.";
            });
          }
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF16122D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.lock_outline, color: Colors.purpleAccent, size: 20),
              SizedBox(width: 10),
              Text("Changer mon mot de passe", style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ancienCtrl,
                  obscureText: obscureAncien,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Mot de passe actuel",
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    suffixIcon: IconButton(
                      icon: Icon(obscureAncien ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.white38, size: 18),
                      onPressed: () => setModalState(() => obscureAncien = !obscureAncien),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nouveauCtrl,
                  obscureText: obscureNouveau,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Nouveau mot de passe",
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNouveau ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.white38, size: 18),
                      onPressed: () => setModalState(() => obscureNouveau = !obscureNouveau),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureNouveau,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Confirmer le nouveau mot de passe",
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