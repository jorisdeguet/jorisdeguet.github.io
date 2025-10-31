# Configuration Firebase - SuperTâche

## Étapes de configuration rapide

### 1. Installer FlutterFire CLI (une seule fois)
```bash
dart pub global activate flutterfire_cli
```

### 2. Configurer Firebase pour ce projet
```bash
cd /Users/jorisdeguet/Documents/GitHub/jorisdeguet.github.io/supertache
flutterfire configure
```

Cela va :
- Vous demander de vous connecter à votre compte Google
- Vous permettre de sélectionner ou créer un projet Firebase
- Générer automatiquement le fichier `lib/firebase_options.dart`
- Configurer Firebase pour iOS, Android et Web

### 3. Activer les services Firebase

Dans la [Console Firebase](https://console.firebase.google.com/), pour votre projet :

#### Authentication
1. Allez dans **Authentication** → **Sign-in method**
2. Activez **Email/Password**

#### Firestore Database
1. Allez dans **Firestore Database** → **Create database**
2. Choisissez le mode **Test mode** (ou Production avec les règles ci-dessous)
3. Sélectionnez une région proche de vous

#### Règles Firestore (à copier dans l'onglet "Règles")
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    match /enseignants/{enseignantId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == enseignantId;
    }
    
    match /groupes/{groupeId} {
      allow read, write: if request.auth != null;
    }
    
    match /taches_individuelles/{tacheId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    match /taches_completes/{tacheId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 4. Tester l'application

```bash
# Pour Web
flutter run -d chrome

# Pour Android (avec émulateur ou appareil connecté)
flutter run -d android

# Pour iOS (sur macOS uniquement)
flutter run -d ios
```

### 5. Premier utilisateur

Au premier lancement :
1. Cliquez sur "Créer un compte"
2. Remplissez le formulaire d'inscription
3. Une fois connecté, vous pourrez :
   - Créer une session (ex: Automne 2024)
   - Importer des groupes
   - Affecter des groupes à votre tâche

## Troubleshooting

### Erreur "Firebase not initialized"
→ Assurez-vous d'avoir exécuté `flutterfire configure`

### Erreur lors de la compilation
→ Exécutez `flutter clean` puis `flutter pub get`

### Problèmes d'authentification
→ Vérifiez que Email/Password est bien activé dans Firebase Console

### Erreurs Firestore
→ Vérifiez que les règles de sécurité sont bien configurées
