import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'director_view.dart'; // DirectorDashboardView
import 'main.dart';           // MainDashboard (si elle est dans main.dart)
import 'auth_manager.dart';



// Garde tes imports existants ici (DirectorDashboardView, MainDashboard,
// AuthManager, etc.) — ce fichier ne touche qu'à LoginScreen.

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  String _error = "";
  bool _obscurePw = true;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // Boucle lente et discrète pour la trajectoire de vol en fond du panneau
  // de marque — le seul élément "signature" de cet écran, tout le reste
  // reste sobre.
  late final AnimationController _pathController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -10.0).chain(CurveTween(curve: Curves.ease)), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -10.0, end: 10.0).chain(CurveTween(curve: Curves.ease)), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 10.0, end: -8.0).chain(CurveTween(curve: Curves.ease)), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -8.0, end: 8.0).chain(CurveTween(curve: Curves.ease)), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 8.0, end: 0.0).chain(CurveTween(curve: Curves.ease)), weight: 1),
    ]).animate(_shakeController);

    _pathController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pathController.dispose();
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    // --- CONNEXION SPÉCIALE DIRECTEUR PNR ---
    if (_idController.text == 'DEXpnr' && _pwController.text == '1234') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DirectorDashboardView(targetCity: 'PNR')),
      );
      return;
    }

    // --- CONNEXION SPÉCIALE DIRECTEUR BZV ---
    if (_idController.text == 'DEXbzv' && _pwController.text == '1234') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DirectorDashboardView(targetCity: 'BZV')),
      );
      return;
    }

    // --- CONNEXION STANDARD ---
    if (AuthManager.login(_idController.text, _pwController.text)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainDashboard()),
      );
    } else {
      SystemSound.play(SystemSoundType.alert);
      _shakeController.forward(from: 0);
      setState(() => _error = "Identifiant ou mot de passe incorrect");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07041A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth > 900;
          return Row(
            children: [
              if (isWide) Expanded(flex: 5, child: _buildBrandPanel()),
              Expanded(
                flex: isWide ? 4 : 1,
                child: Container(
                  color: const Color(0xFF0A051D),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                      child: _buildFormCard(compact: !isWide),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // PANNEAU DE MARQUE (visible sur fenêtre large — desktop)
  // ---------------------------------------------------------------------
  Widget _buildBrandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF120B33), Color(0xFF1A1147), Color(0xFF241659)],
        ),
      ),
      child: Stack(
        children: [
          // Trajectoire de vol animée — signature discrète, faible opacité.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pathController,
              builder: (context, _) => CustomPaint(
                painter: _FlightPathPainter(progress: _pathController.value),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFB27CFF), Color(0xFFE879F9)]),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      "DASHDARK",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 56),
                const Text(
                  "Chaque agent compte.\nChaque note aussi..",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 380,
                  child: Text(
                    "Évaluation et suivi du personnel d'escale — Passage, "
                    "Piste, Ops, Fret et Garage, coordonnés en un seul "
                    "tableau de bord.",
                    style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    _stationChip("PNR", "Pointe-Noire"),
                    const SizedBox(width: 10),
                    _stationChip("BZV", "Brazzaville"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationChip(String code, String city) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(code, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(width: 5),
          Text("· $city", style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // CARTE DE CONNEXION
  // ---------------------------------------------------------------------
  Widget _buildFormCard({required bool compact}) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: child,
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.fromLTRB(36, 40, 36, 36),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 20)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compact) ...[
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFB27CFF), Color(0xFFE879F9)]),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text("DASHDARK", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3)),
                ],
              ),
              const SizedBox(height: 28),
            ],
            const Text(
              "ESPACE PERSONNEL",
              style: TextStyle(color: Color(0xFFB794F6), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            const Text(
              "Connexion",
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
            const SizedBox(height: 32),
            _buildField(
              label: "Identifiant",
              controller: _idController,
              icon: Icons.badge_outlined,
              obscure: false,
            ),
            const SizedBox(height: 16),
            _buildField(
              label: "Mot de passe",
              controller: _pwController,
              icon: Icons.lock_outline,
              obscure: _obscurePw,
              suffix: IconButton(
                splashRadius: 18,
                icon: Icon(
                  _obscurePw ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white38,
                  size: 19,
                ),
                onPressed: () => setState(() => _obscurePw = !_obscurePw),
              ),
              onSubmitted: (_) => _handleLogin(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _error.isEmpty
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 28),
            _buildLoginButton(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 12, color: Colors.white24),
                const SizedBox(width: 6),
                Text(
                  "Accès réservé au personnel autorisé",
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool obscure,
    Widget? suffix,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          onSubmitted: onSubmitted,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: const Color(0xFFB27CFF),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            prefixIcon: Icon(icon, size: 18, color: Colors.white38),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFB27CFF), width: 1.4),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFFD946EF)]),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(color: const Color(0xFF9333EA).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: _handleLogin,
            child: const Center(
              child: Text(
                "SE CONNECTER",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Trajectoire de vol animée — élément signature du panneau de marque.
// Un arc pointillé avec un point lumineux qui glisse dessus en boucle,
// évoquant un suivi de vol radar sans être une carte/radar littérale.
// ---------------------------------------------------------------------
class _FlightPathPainter extends CustomPainter {
  final double progress;
  _FlightPathPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.82)
      ..cubicTo(
        size.width * 0.35, size.height * 0.55,
        size.width * 0.55, size.height * 0.95,
        size.width * 0.95, size.height * 0.18,
      );

    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Pointillés
    final metrics = path.computeMetrics().toList();
    for (final metric in metrics) {
      double distance = 0;
      const dashLen = 6.0, gapLen = 7.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), dashPaint);
        distance = next + gapLen;
      }

      // Point lumineux glissant sur la trajectoire
      final tangent = metric.getTangentForOffset(metric.length * progress);
      if (tangent != null) {
        final glowPaint = Paint()
          ..color = const Color(0xFFFBBF24).withOpacity(0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(tangent.position, 4, glowPaint);
        canvas.drawCircle(tangent.position, 2.2, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlightPathPainter oldDelegate) => oldDelegate.progress != progress;
}