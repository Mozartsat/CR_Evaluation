import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_manager.dart';
import 'employee_repository.dart';
import 'evaluation_view.dart';
import 'scores_view.dart';
//import 'director_view.dart'; // <--- AJOUTER CECI
import 'evaluation_unlock_view.dart'; // ← AJOUTER : déblocage évaluations (Rep/Admin)
import 'package:supabase_flutter/supabase_flutter.dart'; // N'oubliez pas cet import
import 'login_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mctubbjpcirzsrfuozqu.supabase.co', // À récupérer sur votre dashboard Supabase
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jdHViYmpwY2lyenNyZnVvenF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc5MjAwNDcsImV4cCI6MjA5MzQ5NjA0N30.gw7K0GkVsPkomGQv8Y6wlOIfFdMW2IPqMqsbgLb7dNM',
  );

  runApp(const DashdarkApp());
}

class DashdarkApp extends StatelessWidget {
  const DashdarkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A051D),
        cardColor: const Color(0xFF16122D),
        primaryColor: Colors.purpleAccent,
      ),
      home: const LoginScreen(),
    );
  }
}





// --- DASHBOARD PRINCIPAL ---
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  String _selectedPage = 'Home';
  bool _isLoadingEmployees = true;
  String _searchQuery = '';
  String _filterFonction = 'Tous';
  
  // Clé pour forcer le rafraîchissement de la sidebar (fermer les menus)
  int _navKey = 0;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    await EmployeeRepository.instance.init();
    setState(() => _isLoadingEmployees = false);
  }

  Widget _getSelectedWidget() {
    //print(">>> _selectedPage = '$_selectedPage'"); // temporaire
    if (_isLoadingEmployees) {
      return const Center(child: CircularProgressIndicator());
    }

    

    if (_selectedPage == 'Home') {return _buildHomePage();}

    final List<String> parts = _selectedPage.split(' : ');
    String category = parts.first;
    String ville = "PNR";
    String service = "";

    if (parts.length > 1) {
      final List<String> subParts = parts.last.split(' - ');
      ville = subParts.first;
      service = subParts.length > 1 ? subParts.last : "";
    }

    if (category == "Gestion du personnel") {
      return _buildPersonnelManagement(ville, service);
    }

    if (category == "Score") {
      final displayedEmployees = EmployeeRepository.instance.getByCityService(
        ville,
        service,
      );
      final allCityEmployees = EmployeeRepository.instance.employees
          .where((e) => e['ville'] == ville)
          .toList();
      return ScoreView(
        employees: displayedEmployees,
        allCityEmployees: allCityEmployees,
      );
    }

    if (category == "Déblocage évaluations") {
      return EvaluationUnlockView(
        ville: ville,
        initialService: service,
        allowServicePicker: false,
        debloquePar: AuthManager.currentUserID ?? AuthManager.currentUserRole,
        canDeleteSessions: true, // Rep et Admin peuvent supprimer des sessions
      );
    }


    if (category == "Évaluation du personnel") {
      return EvaluationPersonnelView(
        employees: EmployeeRepository.instance.employees,
        targetVille: ville,
        targetService: service,
        onUpdate: () async {
      
      // 2. Recharger les données proprement
                 await EmployeeRepository.instance.init();
           if (mounted) {
          setState(() {});
          }
        },
      );
    }

    return const Center(child: Text("Sélectionnez un service"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            // Clé dynamique : change pour réinitialiser les ExpansionTiles
            key: ValueKey('nav_$_navKey'),
            width: 260,
            color: const Color(0xFF0F0A25),
            child: Column(
              children: [
                _buildLogo(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildNavItem(Icons.home_filled, 'Home'),
                      const Divider(color: Colors.white10),
                      if (AuthManager.currentUserRole == "rep" ||
                          AuthManager.currentUserRole == "admin") ...[
                        _buildGoldSectionTitle('RESPONSABLE'),
                        _buildExpansionMenu(
                          icon: Icons.people_outline,
                          title: "Personnel",
                          children: [_buildCityTree("Gestion du personnel")],
                        ),
                        _buildExpansionMenu(
                            icon: Icons.analytics_outlined,
                             title: "Scores",
  children: [
    if (AuthManager.canSeeCity("PNR")) _buildCitySubMenu("Score", "PNR"),
    if (AuthManager.canSeeCity("BZV")) _buildCitySubMenu("Score", "BZV"),
  ],
),
                        _buildExpansionMenu(
                          icon: Icons.lock_open_outlined,
                          title: "Déblocage évaluations",
                          children: [
                            _buildCityTree("Déblocage évaluations"),
                          ],
                        ),
                      ],
                      if (AuthManager.currentUserRole == "sup" ||
                          AuthManager.currentUserRole == "admin") ...[
                        const Divider(color: Colors.white10),
                        _buildGoldSectionTitle('SUPERVISEUR'),
                        _buildCityTree("Évaluation du personnel"),
                      ],
                     ],
              ),
            ),

            // ← INSÉRER ICI le bouton reset (visible uniquement pour les 'rep')
            if (AuthManager.currentUserRole == 'rep') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                  label: Text(
                    'Réinitialiser ${AuthManager.currentUserServices.join('+')} · ${AuthManager.currentUserCity}',
                    style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: const Size(double.infinity, 36),
                  ),
                  onPressed: () => _confirmReset(context),
                ),
              ),
            ],

                _buildUserProfile(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPage,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: _getSelectedWidget()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildHomePage() {
  final service = AuthManager.currentUserServices.isNotEmpty
      ? AuthManager.currentUserServices.first
      : '';
 
  String imagePath;
  String titre;
  String description;
 
  switch (service.toLowerCase()) {
    case 'passage':
      imagePath = 'assets/images/passage.jpg';
      titre = 'Service aux Passagers';
      description = 'Accueil et assistance des passagers au sol';
      break;
    case 'piste':
      imagePath = 'assets/images/piste.jpg';
      titre = 'Service Piste';
      description = 'Assistance avion & Coordinateur de vol / Chef Avion';
      break;
    case 'ops':
      imagePath = 'assets/images/ops.jpeg';
      titre = 'Service Piste & Opérations';
      description = 'Assistance avion & Coordinateur de vol / Chef Avion';
      break;
    case 'fret':
      imagePath = 'assets/images/fret.jpg';
      titre = 'Service Fret';
      description = 'Traitement et acheminement du fret aérien';
      break;
    case 'garage':
      imagePath = 'assets/images/garage.png';
      titre = 'Service Garage';
      description = 'Maintenance et entretien des engins GSE';
      break;
    default:
      imagePath = '';
      titre = 'DashDark';
      description = 'Tableau de bord de gestion du personnel';
  }
 
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (imagePath.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            // Image.asset : embarquée dans l'app, aucune dépendance réseau,
            // donc aucun souci de DNS/proxy/filtre à la maison ou ailleurs.
            child: Image.asset(
              imagePath,
              width: 600,
              height: 340,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackHome(titre, description),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          titre,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
          ),
          child: Text(
            "${AuthManager.currentUserCity} · ${AuthManager.currentUserID ?? ''}",
            style: const TextStyle(color: Colors.purpleAccent, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

Widget _buildFallbackHome(String titre, String description) {
  return Container(
    width: 600,
    height: 340,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.flight_takeoff, size: 64, color: Colors.white24),
        const SizedBox(height: 16),
        Text(titre, style: const TextStyle(color: Colors.white38, fontSize: 18)),
      ],
    ),
  );
}
   
  // --- HELPERS UI ---
  Widget _buildLogo() => const Padding(
    padding: EdgeInsets.all(25),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.dashboard, size: 28, color: Colors.purpleAccent),
        SizedBox(width: 10),
        Text(
          "DashDark",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _buildNavItem(IconData icon, String title) => ListTile(
    leading: Icon(
      icon,
      color: _selectedPage == title ? Colors.purpleAccent : Colors.white54,
      size: 20,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: _selectedPage == title ? Colors.white : Colors.white54,
        fontSize: 13,
      ),
    ),
    onTap: () {
      setState(() {
        // LOGIQUE DE FERMETURE DES MENUS
        if (title == 'Home') {
          _selectedPage = 'Home';
          _navKey++; // Change la clé pour reconstruire le sidebar (ferme les menus)
        } else {
          _selectedPage = title;
        }
      });
    },
  );

  Widget _buildGoldSectionTitle(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.amber,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _buildExpansionMenu({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) => ExpansionTile(
    leading: Icon(icon, color: Colors.white54, size: 20),
    title: Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 13),
    ),
    children: children,
  );

  Widget _buildCityTree(String parentName) => ExpansionTile(
    title: Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(parentName, style: const TextStyle(fontSize: 12)),
    ),
    children: [
      if (AuthManager.canSeeCity("PNR")) _buildCitySubMenu(parentName, "PNR"),
      if (AuthManager.canSeeCity("BZV")) _buildCitySubMenu(parentName, "BZV"),
    ],
  );

  Widget _buildCitySubMenu(String cat, String city) => ExpansionTile(
    title: Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Text(
        city,
        style: const TextStyle(fontSize: 12, color: Colors.purpleAccent),
      ),
    ),
    children: [
      'Passage',
      'Ops',
      'Piste',
      'Fret',
      'Garage',
    ].map((s) => _buildServiceItem(cat, city, s)).toList(),
  );

  Widget _buildServiceItem(String cat, String city, String s) {
    final label = "$cat : $city - $s";
    final bool hasAccess = AuthManager.hasAccess(label);
    final bool isSelected = _selectedPage == label;

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 50, right: 20),
      dense: true,
      enabled: hasAccess,
      onTap: hasAccess ? () => setState(() => _selectedPage = label) : null,
      title: Text(
        s,
        style: TextStyle(
          fontSize: 13,
          color: hasAccess
              ? (isSelected ? Colors.purpleAccent : Colors.white70)
              : Colors.white24,
        ),
      ),
      trailing: hasAccess
          ? null
          : const Icon(Icons.lock_outline, size: 12, color: Colors.white24),
    );
  }

  Widget _buildPersonnelManagement(String ville, String service) {
  final allEmployees = EmployeeRepository.instance.getByCityService(ville, service);
  final Map<String, List<Map<String, dynamic>>> parFonction = {};
  for (final emp in allEmployees) {
    final fonction = emp['fonction'] ?? 'Autre';
    parFonction.putIfAbsent(fonction, () => []).add(emp);
  }
  for (final liste in parFonction.values) {
    liste.sort((a, b) {
      final nomCompare = (a['nom'] ?? '').toString().toLowerCase()
          .compareTo((b['nom'] ?? '').toString().toLowerCase());
      if (nomCompare != 0) return nomCompare;
      return (a['prenom'] ?? '').toString().toLowerCase()
          .compareTo((b['prenom'] ?? '').toString().toLowerCase());
    });
  }
  final fonctions = parFonction.keys.toList()..sort();
   // ← AJOUTER ICI le filtre
  final Map<String, List<Map<String, dynamic>>> parFonctionFiltre = {};
  for (final entry in parFonction.entries) {
    if (_filterFonction != 'Tous' && entry.key != _filterFonction) continue;
    final filtered = entry.value.where((emp) {
      final q = _searchQuery.toLowerCase();
      if (q.isEmpty) return true;
      return (emp['nom'] ?? '').toLowerCase().contains(q) ||
          (emp['prenom'] ?? '').toLowerCase().contains(q);
    }).toList();
    if (filtered.isNotEmpty) parFonctionFiltre[entry.key] = filtered;
  }
  final fonctionsFiltrees = parFonctionFiltre.keys.toList()..sort();

  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TOOLBAR
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // TOOLBAR
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(children: [
      ElevatedButton.icon(
        onPressed: () => _showEmployeeDialog(ville, service),
        icon: const Icon(Icons.person_add, size: 16),
        label: const Text("Ajouter"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purpleAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          "${allEmployees.length} agents · $ville – $service",
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ),
    ]),
    const SizedBox(width: 10),
    Row(children: [
      // FILTRE FONCTION
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0A25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _filterFonction,
            dropdownColor: const Color(0xFF16122D),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            iconEnabledColor: Colors.white38,
            items: ['Tous', ...fonctions]
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (v) => setState(() => _filterFonction = v ?? 'Tous'),
          ),
        ),
      ),
      const SizedBox(width: 10),
      // BARRE DE RECHERCHE
      Container(
        width: 220,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0A25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Rechercher nom / prénom…',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 16),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: const Icon(Icons.close, color: Colors.white24, size: 14),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: () => setState(() {
          _searchQuery = '';
          _filterFonction = 'Tous';
        }),
        icon: const Icon(Icons.refresh, color: Colors.white38, size: 18),
      ),
    ]),
  ],
),
            
          ],
        ),
        const SizedBox(height: 16),

        // STAT CARDS DYNAMIQUES
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _hoverZoom(
                child: _statCard(
                  "Total",
                  allEmployees.length.toString(),
                  "agents enregistrés",
                  Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 10),
              ...fonctions.map((f) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _hoverZoom(
                  child: _statCard(
                    f,
                    parFonction[f]!.length.toString(),
                    "enregistrés",
                    _fonctionColor(f),
                  ),
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // COLONNES DYNAMIQUES PAR FONCTION
        if (fonctions.isEmpty)
          const Center(
            child: Text("Aucun agent", style: TextStyle(color: Colors.white38)),
          )
        else
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: fonctionsFiltrees.map((fonction) {
  final employees = parFonctionFiltre[fonction]!;
              return _hoverZoom(
                child: SizedBox(
                  width: fonctions.length >= 2
                      ? (MediaQuery.of(context).size.width - 340) / 2
                      : double.infinity,
                  child: _buildGenderColumn(
                    title: fonction,
                    icon: Icons.work_outline,
                    color: _fonctionColor(fonction),
                    employees: employees,
                    ville: ville,
                    service: service,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    ),
  );
}

  
 
 Color _fonctionColor(String fonction) {
  switch (fonction.toLowerCase()) {
    case 'agent': return Colors.orangeAccent;
    case 'gdv': return Colors.blueAccent;
    case 'coordo': return Colors.blueAccent;
    case 'superviseur': return Colors.purpleAccent;
    case 'cza': return Colors.tealAccent;
    default: return Colors.white54;
  }
}

  

  void _showEmployeeDialog(
    String defaultVille,
    String defaultService, {
    Map<String, dynamic>? existingEmployee,
  }) {
    final nomController = TextEditingController(
      text: existingEmployee != null ? existingEmployee['nom'] : '',
    );
    final prenomController = TextEditingController(
      text: existingEmployee != null ? existingEmployee['prenom'] : '',
    );
    final fonctionController = TextEditingController(
      text: existingEmployee != null ? existingEmployee['fonction'] : '',
    );
    final serviceController = TextEditingController(
      text: existingEmployee != null
          ? existingEmployee['service']
          : defaultService,
    );
    final dateController = TextEditingController(
      text: existingEmployee != null
          ? (existingEmployee['dateEmbauche'] ?? '')
          : '',
    );
    String selectedGenre = existingEmployee != null
        ? (existingEmployee['genre'] ?? '')
        : '';
    bool canSave =
        nomController.text.trim().isNotEmpty &&
        prenomController.text.trim().isNotEmpty &&
        fonctionController.text.trim().isNotEmpty &&
        serviceController.text.trim().isNotEmpty &&
        selectedGenre.isNotEmpty;

    void updateCanSave(StateSetter setModalState) {
      final isValid =
          nomController.text.trim().isNotEmpty &&
          prenomController.text.trim().isNotEmpty &&
          fonctionController.text.trim().isNotEmpty &&
          serviceController.text.trim().isNotEmpty &&
          selectedGenre.isNotEmpty;
      if (isValid != canSave) {
        setModalState(() => canSave = isValid);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: const Color(0xFF16122D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(24),


                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existingEmployee == null
                          ? "Ajouter un employé"
                          : "Modifier un employé",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: "Nom",
                      controller: nomController,
                      icon: Icons.badge,
                      onChanged: () => updateCanSave(setModalState),
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      label: "Prénom",
                      controller: prenomController,
                      icon: Icons.person,
                      onChanged: () => updateCanSave(setModalState),
                    ),
                    const SizedBox(height: 12),

   DropdownMenu<String>(
  controller: fonctionController,
  width: 370,
  enableFilter: true,
  enableSearch: true,
  requestFocusOnTap: true,
  label: const Text('Fonction'),
  leadingIcon: const Icon(Icons.work_outline, color: Colors.white54),
  textStyle: const TextStyle(color: Colors.white),
  menuStyle: MenuStyle(
    backgroundColor: WidgetStateProperty.all(const Color(0xFF16122D)),
    elevation: WidgetStateProperty.all(8),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF0F0A25),
    labelStyle: const TextStyle(color: Colors.white54),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  ),
  onSelected: (String? value) {
    if (value != null) {
      fonctionController.text = value;
      updateCanSave(setModalState);
    }
  },
  dropdownMenuEntries: ['Agent', 'CZA', 'Coordo', 'GDV', 'Superviseur']
      .map((f) => DropdownMenuEntry<String>(
            value: f,
            label: f,
            leadingIcon: const Icon(Icons.work_outline, size: 16, color: Colors.white54),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(Colors.white),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.hovered)) {
                  return Colors.purpleAccent.withOpacity(0.2);
                }
                return const Color(0xFF16122D);
              }),
            ),
          ))
      .toList(),
),
    const SizedBox(height: 12),
  
   


  Autocomplete<String>(
  optionsBuilder: (TextEditingValue textEditingValue) {
    const genres = ['Masculin', 'Féminin'];
    if (textEditingValue.text.isEmpty) return genres;
    return genres.where((g) =>
        g.toLowerCase().contains(textEditingValue.text.toLowerCase()));
  },
  initialValue: TextEditingValue(
    text: selectedGenre == 'M' ? 'Masculin' : selectedGenre == 'F' ? 'Féminin' : '',
  ),
  onSelected: (String value) {
    setModalState(() {
      selectedGenre = value == 'Masculin' ? 'M' : 'F';
    });
    updateCanSave(setModalState);
  },
  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(color: Colors.white),
      onChanged: (val) => updateCanSave(setModalState),
      decoration: InputDecoration(
        labelText: 'Genre',
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0F0A25),
        prefixIcon: Icon(
          selectedGenre == 'M'
              ? Icons.male
              : selectedGenre == 'F'
                  ? Icons.female
                  : Icons.person_outline,
          color: selectedGenre == 'M'
              ? Colors.blueAccent
              : selectedGenre == 'F'
                  ? Colors.pinkAccent
                  : Colors.white54,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  },
  optionsViewBuilder: (context, onSelected, options) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: const Color(0xFF16122D),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 370,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              final isMale = option == 'Masculin';
              return ListTile(
                leading: Icon(
                  isMale ? Icons.male : Icons.female,
                  color: isMale ? Colors.blueAccent : Colors.pinkAccent,
                  size: 18,
                ),
                title: Text(
                  option,
                  style: TextStyle(
                    color: isMale ? Colors.blueAccent : Colors.pinkAccent,
                    fontSize: 13,
                  ),
                ),
                onTap: () => onSelected(option),
                hoverColor: Colors.white10,
              );
            },
          ),
        ),
      ),
    );
  },
),
                    const SizedBox(height: 12),
                    _buildInputField(
                      label: "Service",
                      controller: serviceController,
                      icon: Icons.apartment,
                      onChanged: () => updateCanSave(setModalState),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
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
                        if (date != null) {
                          dateController.text =
                              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                          setModalState(() {});
                        }
                      },
                      child: AbsorbPointer(
                        child: _buildInputField(
                          label: "Date d'embauche (optionnelle)",
                          controller: dateController,
                          icon: Icons.calendar_today,
                          suffixIcon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white54,
                          ),
                          onChanged: () {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: canSave
                              ? () async {

                                  final nomSaisi = nomController.text.trim();
                                  final prenomSaisi = prenomController.text.trim();
                                  final doublonExiste = EmployeeRepository.instance.employeeExists(
                                    nomSaisi,
                                    prenomSaisi,
                                    excludeId: existingEmployee?['id'],
                                  );
                                  if (doublonExiste) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Un agent nommé "$nomSaisi $prenomSaisi" existe déjà.',
                                        ),
                                        backgroundColor: Colors.red.shade700,
                                      ),
                                    );
                                    return;
                                  }

                                  final employeeData = {
                                    'id': existingEmployee != null
                                        ? existingEmployee['id']
                                        : DateTime.now().millisecondsSinceEpoch
                                              .toString(),
                                    'nom': nomController.text
                                        .trim()
                                        .toUpperCase(),
                                    'prenom': prenomController.text.trim(),
                                    'fonction': fonctionController.text.trim(),
                                    'genre': selectedGenre,
                                    'ville': defaultVille,
                                    'service': serviceController.text.trim(),
                                    'dateEmbauche': dateController.text.isEmpty
                                        ? null
                                        : dateController.text,
                                    'isValidated': existingEmployee != null
                                        ? (existingEmployee['isValidated'] ??
                                              false)
                                        : false,
                                    'evaluationScore': existingEmployee != null
                                        ? existingEmployee['evaluationScore']
                                        : null,
                                    'evaluationSelections':
                                        existingEmployee != null
                                        ? existingEmployee['evaluationSelections']
                                        : null,
                                  };
                                  if (existingEmployee != null) {
                                    try {
  await EmployeeRepository.instance.updateEmployee(employeeData);
} on SupabaseUnavailableException catch (e) {
  if (mounted) _showConnectionError(context, e.message);
  return;
}
                                  } else {

                                    try {
  await EmployeeRepository.instance.addEmployee(employeeData);
} on SupabaseUnavailableException catch (e) {
  if (mounted) _showConnectionError(context, e.message);
  return; // stoppe la fermeture du dialog
}

                                  }
                                  setState(() {});
                                  Navigator.pop(context);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            disabledBackgroundColor: Colors.white12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            existingEmployee == null
                                ? "ENREGISTRER"
                                : "SAUVEGARDER",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statCard(String label, String value, String sub, Color color) {
  return Container(
    width: 140, // ← largeur fixe au lieu de Expanded
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color)),
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.white24)),
      ],
    ),
  );
}

  Widget _hoverZoom({required Widget child}) {
    bool hovered = false;
  return StatefulBuilder(
    builder: (context, setState) {
      
      return MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: AnimatedScale(
          scale: hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: child,
        ),
      );
    },
  );
}


 Widget _buildGenderColumn({
  required String title,
  required IconData icon,
  required Color color,
  required List<Map<String, dynamic>> employees,
  required String ville,
  required String service,
}) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF16122D),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      children: [
        // EN-TÊTE COLONNE
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${employees.length}",
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),

        // LISTE
        if (employees.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              "Aucun agent",
              style: TextStyle(fontSize: 12, color: Colors.white24),
            ),
          )
        else
          Column(
            children: List.generate(employees.length, (index) {
              final emp = employees[index];
              return Column(
                children: [
                  if (index > 0) const Divider(color: Colors.white10, height: 1),
                  _hoverZoom(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        // NUMÉRO
                        SizedBox(
                          width: 18,
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(fontSize: 11, color: Colors.white24),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // AVATAR
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: color.withOpacity(0.15),
                          child: Text(
                            emp['nom'][0],
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // INFO
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${emp['nom']} ${emp['prenom']}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                emp['fonction'] ?? '',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // BADGE FONCTION
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            emp['fonction'] ?? '',
                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // BOUTON EDIT
                        _hoverZoom(
                          child: IconButton(
                            icon: const Icon(Icons.edit, size: 15, color: Colors.white38),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => _showEmployeeDialog(ville, service, existingEmployee: emp,),
                          ),
                        ),
                        // BOUTON DELETE
                        _hoverZoom(
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () async {
                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF16122D),
                                  title: const Text(
                                    'Confirmer',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: const Text(
                                    'Supprimer cet agent ?',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text(
                                        'Annuler',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      child: const Text('Supprimer'),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                              if (shouldDelete) {
                                try {
                                  await EmployeeRepository.instance.removeEmployee(emp['id']);
                                  setState(() {});
                                } on SupabaseUnavailableException catch (e) {
                                  if (mounted) _showConnectionError(context, e.message);
                                }
                              }
                            },
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              );
            }),
          ),
      ],
    ),
  );
}

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0F0A25),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  

  Widget _buildUserProfile() => ListTile(
    leading: const CircleAvatar(
      radius: 15,
      backgroundColor: Colors.purpleAccent,
      child: Icon(Icons.person, size: 15, color: Colors.white),
    ),
    title: Text(
      AuthManager.currentUserID ?? "User",
      style: const TextStyle(fontSize: 12),
    ),
    trailing: IconButton(
      icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
      onPressed: () {
        AuthManager.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      },
    ),
  );

  void _confirmReset(BuildContext context) {
  final services = AuthManager.currentUserServices.toList();
  final ville = AuthManager.currentUserCity;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF16122D),
      title: const Text('Confirmer la réinitialisation',
          style: TextStyle(color: Colors.white)),
      content: Text(
        'Supprimer tous les agents et évaluations\n'
        'des services ${services.join(', ')} à $ville ?\n\n'
        'Cette action est irréversible.',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await EmployeeRepository.instance.resetByServiceVille(
              services: services,
              ville: ville,
            );
            setState(() {});
          },
          child: const Text('Supprimer',
              style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
}

  void _showConnectionError(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF16122D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.wifi_off, color: Colors.redAccent, size: 48),
      title: const Text(
        "Base de données inaccessible",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      actions: [
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Réessayer"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
      ],
    ),
  );
}

}