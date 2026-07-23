class AuthManager {
  static String? currentUserID;
  static String currentUserCity = 'PNR';
  static Set<String> currentUserServices = {};
  static String currentUserRole = 'rep';
  static bool get isRep => currentUserRole == 'rep';

  // Rep et Admin peuvent débloquer une évaluation verrouillée (>48h).
  // DEX passe par un autre écran (director_view.dart) qui n'utilise pas
  // AuthManager, mais utilise directement le même mécanisme de déblocage
  // côté EmployeeRepository.
  static bool get canUnlockEvaluations =>
      currentUserRole == 'rep' || currentUserRole == 'admin';


  static final Map<String, Map<String, dynamic>> _users = {
    'admin': {'password': '1234', 'city': 'ALL', 'services': ['Passage', 'Ops', 'Piste', 'Fret', 'Garage'], 'role': 'admin'},
    'repkppnr': {'password': '1234', 'city': 'PNR', 'services': ['Passage'], 'role': 'rep'},
    'repopspnr': {'password': '1234', 'city': 'PNR', 'services': ['Ops', 'Piste'], 'role': 'rep'},
    'repfretpnr': {'password': '1234', 'city': 'PNR', 'services': ['Fret'], 'role': 'rep'},
    'repgrgpnr': {'password': '1234', 'city': 'PNR', 'services': ['Garage'], 'role': 'rep'},
    'repkpbzv': {'password': '1234', 'city': 'BZV', 'services': ['Passage'], 'role': 'rep'},
    'repopsbzv': {'password': '1234', 'city': 'BZV', 'services': ['Ops', 'Piste'], 'role': 'rep'},
    'repfretbzv': {'password': '1234', 'city': 'BZV', 'services': ['Fret'], 'role': 'rep'},
    'repgrgbzv': {'password': '1234', 'city': 'BZV', 'services': ['Garage'], 'role': 'rep'},
    'supkppnr': {'password': '1234', 'city': 'PNR', 'services': ['Passage'], 'role': 'sup'},
    'supkpbzv': {'password': '1234', 'city': 'BZV', 'services': ['Passage'], 'role': 'sup'},
    'supopspnr': {'password': '1234', 'city': 'PNR', 'services': ['Ops'], 'role': 'sup'},
    'supopsbzv': {'password': '1234', 'city': 'BZV', 'services': ['Ops'], 'role': 'sup'},
    'supfretpnr': {'password': '1234', 'city': 'PNR', 'services': ['Fret'], 'role': 'sup'},
    'supfretbzv': {'password': '1234', 'city': 'BZV', 'services': ['Fret'], 'role': 'sup'},
    'supgrgpnr': {'password': '1234', 'city': 'PNR', 'services': ['Garage'], 'role': 'sup'},
    'supgrgbzv': {'password': '1234', 'city': 'BZV', 'services': ['Garage'], 'role': 'sup'},
    'suppistepnr': {'password': '1234', 'city': 'PNR', 'services': ['Piste'], 'role': 'sup'},
    'suppistebzv': {'password': '1234', 'city': 'BZV', 'services': ['Piste'], 'role': 'sup'},
  };

  static bool login(String id, String pw) {
    final user = _users[id];
    if (user != null && user['password'] == pw) {
      currentUserID = id;
      currentUserCity = user['city'] as String;
      currentUserServices = Set<String>.from(user['services'] as List<dynamic>);
      currentUserRole = user['role'] as String;
      return true;
    }
    return false;
  }

  static bool canSeeCity(String city) {
    if (currentUserID == null) return false;
    if (currentUserCity == 'ALL') return true;
    return currentUserCity == city;
  }

  static bool hasAccess(String label) {
    if (currentUserID == null) return false;
    if (currentUserID == 'admin') return true;

    final parts = label.split(' : ');
    if (parts.length < 2) return false;
    final segments = parts.last.split(' - ');
    if (segments.length < 2) return false;
    final city = segments.first;
    final service = segments.last;
    return currentUserCity == city && currentUserServices.contains(service);
  }

  static void logout() {
    currentUserID = null;
    currentUserCity = 'PNR';
    currentUserServices = {};
    currentUserRole = 'rep';
  }

  // Retourne la juridiction du rep connecté (services + ville)
static Map<String, dynamic>? get juridiction {
  if (!isRep) return null;
  return {
    'services': currentUserServices.toList(),
    'ville': currentUserCity,
  };
}



}