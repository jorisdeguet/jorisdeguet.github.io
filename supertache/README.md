# SuperTâche

Application Flutter pour la gestion des tâches d'enseignement avec Firebase.

## Fonctionnalités

- **Authentification** : Connexion et inscription avec Firebase Auth
- **Sessions** : Gestion des sessions d'automne et d'hiver
- **Groupes** : Importation et gestion des groupes de cours
  - Format de numéro de cours : 420-XXX-EM
  - Import facile via copier-coller
- **Tâches** : Affectation des groupes aux enseignants
  - Calcul automatique de la CI (Charge Individuelle)
  - Vue d'ensemble de toutes les tâches

## Configuration Firebase

### 1. Créer un projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Créez un nouveau projet ou utilisez un projet existant
3. Activez **Firebase Authentication** avec le provider Email/Password
4. Activez **Cloud Firestore** en mode test (ou avec vos règles de sécurité)

### 2. Installer FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### 3. Configurer Firebase pour votre application

Depuis le dossier racine du projet :

```bash
flutterfire configure
```

Suivez les instructions pour :
- Sélectionner votre projet Firebase
- Choisir les plateformes (iOS, Android, Web)

Cela créera automatiquement le fichier `lib/firebase_options.dart` nécessaire.

### 4. Modifier main.dart pour utiliser les options Firebase

Le fichier `main.dart` doit déjà être configuré, mais assurez-vous qu'il contient :

```dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

### 5. Règles Firestore (règles de base pour le développement)

Dans la console Firebase, configurez ces règles Firestore :

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Sessions - lecture pour tous, écriture pour utilisateurs authentifiés
    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Enseignants - lecture pour tous, écriture pour l'utilisateur correspondant
    match /enseignants/{enseignantId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == enseignantId;
    }
    
    // Groupes - lecture/écriture pour tous les utilisateurs authentifiés
    match /groupes/{groupeId} {
      allow read, write: if request.auth != null;
    }
    
    // Tâches individuelles - lecture pour tous, écriture pour l'enseignant concerné
    match /taches_individuelles/{tacheId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Tâches complètes - lecture pour tous, écriture pour utilisateurs authentifiés
    match /taches_completes/{tacheId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Lancer l'application

### Pour le développement

```bash
flutter run
```

### Pour une plateforme spécifique

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# Web
flutter run -d chrome
```

## Structure du projet

```
lib/
├── models/              # Modèles de données
│   ├── enseignant.dart
│   ├── groupe.dart
│   ├── session.dart
│   ├── tache_complete.dart
│   └── tache_individuelle.dart
├── screens/             # Écrans de l'application
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── groupes/
│   │   ├── groupes_screen.dart
│   │   └── import_groupes_screen.dart
│   ├── sessions/
│   │   └── sessions_screen.dart
│   ├── taches/
│   │   ├── affecter_groupes_screen.dart
│   │   └── taches_screen.dart
│   └── home_screen.dart
├── services/            # Services Firebase
│   ├── auth_service.dart
│   └── firestore_service.dart
└── main.dart           # Point d'entrée
```

## Format d'importation des groupes

Lors de l'importation des groupes, utilisez le format suivant (une ligne par groupe) :

```
420-SN1-EM, Programmation I, 35, 1.5
420-SN2-EM, Programmation II, 30, 1.5
420-BD1-EM, Bases de données I, 32, 1.2
```

Format : `Numéro de cours, Nom du cours, Nombre d'étudiants, CI`

Les séparateurs acceptés sont : virgules, tabulations, ou espaces multiples.

## Développement futur

- [ ] Export des tâches en PDF
- [ ] Statistiques sur les CI par enseignant
- [ ] Historique des modifications
- [ ] Notifications
- [ ] Partage de tâches entre enseignants
- [ ] Import depuis Excel/CSV

## Support

Pour toute question ou problème, consultez la documentation Flutter ou Firebase.
