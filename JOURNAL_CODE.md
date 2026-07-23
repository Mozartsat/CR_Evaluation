# Journal de Code - Application CR_EVAL3

## Vue d'ensemble
Cette application Flutter permet la gestion et l'évaluation du personnel dans une structure organisée par villes et services. Elle utilise une architecture basée sur des widgets Stateful et Stateless, avec persistance via SharedPreferences.

## Classes et Widgets Principaux

### 1. AuthManager (auth_manager.dart)
**Famille :** Singleton de gestion d'authentification  
**Propriétés :**
- `currentUserID` (String?) : ID de l'utilisateur connecté
- `currentUserCity` (String) : Ville de l'utilisateur (défaut: 'PNR')
- `currentUserServices` (Set<String>) : Services accessibles
- `currentUserRole` (String) : Rôle ('rep', 'sup', 'admin')

**Méthodes :**
- `login(String id, String pw)` : Authentifie l'utilisateur
  - Équivalents : Aucune
  - Utilisation : Vérifie les credentials dans la map `_users` et définit les propriétés globales
- `canSeeCity(String city)` : Vérifie l'accès à une ville
- `hasAccess(String label)` : Vérifie l'accès à une page spécifique

**Utilisation :** Gère l'authentification et les permissions utilisateur.

### 2. EmployeeRepository (employee_repository.dart)
**Famille :** Singleton de gestion des données des employés  
**Propriétés :**
- `employees` (List<Map<String, dynamic>>) : Liste des employés

**Méthodes :**
- `init()` : Charge les données depuis SharedPreferences
  - Équivalents : loadEmployees()
  - Utilisation : Appelée au démarrage pour restaurer l'état
- `save()` : Sauvegarde les données dans SharedPreferences
- `getByCityService(String city, String service)` : Filtre les employés
- `addEmployee(Map<String, dynamic> employee)` : Ajoute un employé
- `updateEmployee(Map<String, dynamic> employee)` : Met à jour un employé
- `removeEmployee(String id)` : Supprime un employé

**Utilisation :** Gestion centralisée des données des employés avec persistance.

### 3. MainDashboard (main.dart)
**Famille :** Widget StatefulWidget principal  
**Propriétés d'état :**
- `_selectedPage` (String) : Page actuelle sélectionnée
- `_isLoadingEmployees` (bool) : Indicateur de chargement

**Méthodes :**
- `initState()` : Initialise le repository des employés
- `_getSelectedWidget()` : Retourne le widget selon la page sélectionnée
- `_buildPersonnelManagement()` : Construit la vue de gestion du personnel
- `_showEmployeeDialog()` : Affiche le dialogue d'ajout/modification

**Utilisation :** Interface principale avec navigation latérale et contenu dynamique.

### 4. EvaluationPersonnelView (evaluation_view.dart)
**Famille :** Widget StatefulWidget pour l'évaluation  
**Propriétés :**
- `employees` : Liste des employés
- `targetVille`, `targetService` : Filtres
- `onUpdate` : Callback de mise à jour

**Méthodes :**
- `_openEvaluationSheet()` : Ouvre le dialogue d'évaluation
- `_buildColumn()` : Construit les colonnes d'agents

**Utilisation :** Interface d'évaluation avec colonnes "Liste des agents" et "Évalués".

### 5. EvaluationDialog (evaluation_view.dart)
**Famille :** Widget StatefulWidget pour le formulaire d'évaluation  
**Propriétés d'état :**
- `_selections` (List<int?>) : Sélections des critères

**Méthodes :**
- `build()` : Construit l'interface avec boutons stylisés
- Validation : Bouton activé seulement si tous les critères sont sélectionnés

**Utilisation :** Formulaire moderne avec boutons horizontaux pour chaque critère.

### 6. ScoreView (scores_view.dart)
**Famille :** Widget StatefulWidget pour les scores  
**Méthodes :**
- `_calculateScore()` : Calcule le score total d'un employé
- `_buildRankingCard()` : Construit la carte de classement

**Utilisation :** Affichage du classement des employés par score.

## Widgets Flutter Utilisés

### Material Design
- `Scaffold` : Structure de base des pages
- `AppBar` : Barre supérieure (non utilisée ici)
- `Drawer` : Menu latéral (remplacé par colonne fixe)
- `ListTile` : Éléments de liste
- `Card` : Cartes pour grouper le contenu
- `TextField` : Champs de saisie
- `ElevatedButton` : Boutons principaux
- `TextButton` : Boutons secondaires
- `IconButton` : Boutons avec icônes
- `RadioListTile` : Sélection radio (remplacé par boutons personnalisés)
- `DropdownButtonFormField` : Menus déroulants
- `GestureDetector` : Détection de gestes
- `Wrap` : Layout flexible horizontal
- `SingleChildScrollView` : Défilement vertical
- `ListView` : Listes défilantes
- `ExpansionTile` : Éléments expansibles

### Animations et Thèmes
- `AnimationController` : Contrôle des animations
- `Tween` : Interpolation de valeurs
- `ThemeData.dark()` : Thème sombre
- `LinearGradient` : Dégradés
- `BoxDecoration` : Décorations personnalisées

## Gestion d'État
- `setState()` : Mise à jour de l'interface
- `StatefulBuilder` : Reconstruction partielle
- Callbacks : Communication entre widgets

## Persistance
- `SharedPreferences` : Stockage local clé-valeur
- JSON encoding/decoding : Sérialisation des données

## Équivalents et Alternatives
- `SharedPreferences` → `sqflite` pour base de données locale
- `ListView` → `GridView` pour layout grille
- `ExpansionTile` → `Accordion` (package externe)
- `GestureDetector` → `InkWell` pour effets visuels

## Bonnes Pratiques Implémentées
- Séparation des responsabilités (Repository, Views)
- Singleton pour données globales
- Validation de formulaires
- Gestion d'erreurs basique
- UI responsive avec MediaQuery
- Thème cohérent et sombre

## Commandes Flutter Utiles
- `flutter run` : Lance l'application
- `flutter build apk` : Construit l'APK Android
- `flutter analyze` : Analyse statique du code
- `flutter pub get` : Télécharge les dépendances
- `flutter pub add <package>` : Ajoute un package

## Structure du Projet
```
lib/
├── main.dart              # Point d'entrée et dashboard
├── auth_manager.dart      # Gestion authentification
├── employee_repository.dart # Gestion données employés
├── evaluation_view.dart   # Vue évaluation
└── scores_view.dart       # Vue scores
```

Ce journal peut être imprimé pour référence lors du développement ou de la maintenance.