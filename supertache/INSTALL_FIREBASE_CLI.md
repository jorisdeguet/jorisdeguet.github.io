╔══════════════════════════════════════════════════════════════════════════════╗
║                  INSTALLATION FIREBASE CLI - INSTRUCTIONS                    ║
╚══════════════════════════════════════════════════════════════════════════════╝

⚠️  Firebase CLI nécessite des permissions sudo. Voici comment l'installer :

OPTION 1 : Installer Firebase CLI via npm (RECOMMANDÉ)
═══════════════════════════════════════════════════════════════════════════════

1. Corriger les permissions npm (si nécessaire) :
   
   sudo chown -R $(whoami) ~/.npm

2. Installer Firebase CLI :
   
   npm install -g firebase-tools

3. Vérifier l'installation :
   
   firebase --version


OPTION 2 : Installer via Homebrew (si vous avez Homebrew)
═══════════════════════════════════════════════════════════════════════════════

1. Installer Firebase CLI :
   
   brew install firebase-cli

2. Vérifier l'installation :
   
   firebase --version


OPTION 3 : Configuration manuelle de Firebase (SANS Firebase CLI)
═══════════════════════════════════════════════════════════════════════════════

Si vous ne voulez pas installer Firebase CLI, vous pouvez configurer manuellement :

1. Allez sur https://console.firebase.google.com/

2. Créez un nouveau projet ou sélectionnez un projet existant

3. Activez les services nécessaires :
   • Authentication (Email/Password)
   • Firestore Database

4. Pour le Web, ajoutez une application Web :
   • Project Settings > General > Your apps
   • Cliquez sur "Add app" et sélectionnez Web
   • Donnez-lui un nom (ex: "SuperTâche Web")
   • Copiez la configuration Firebase

5. Créez manuellement le fichier firebase_options.dart :

   Créez le fichier : lib/firebase_options.dart
   
   Et copiez ce template en remplaçant les valeurs par celles de votre projet :

   ```dart
   import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
   import 'package:flutter/foundation.dart'
       show defaultTargetPlatform, kIsWeb, TargetPlatform;

   class DefaultFirebaseOptions {
     static FirebaseOptions get currentPlatform {
       if (kIsWeb) {
         return web;
       }
       switch (defaultTargetPlatform) {
         case TargetPlatform.android:
           return android;
         case TargetPlatform.iOS:
           return ios;
         default:
           throw UnsupportedError(
             'DefaultFirebaseOptions are not supported for this platform.',
           );
       }
     }

     static const FirebaseOptions web = FirebaseOptions(
       apiKey: 'VOTRE_API_KEY',
       appId: 'VOTRE_APP_ID',
       messagingSenderId: 'VOTRE_SENDER_ID',
       projectId: 'VOTRE_PROJECT_ID',
       authDomain: 'VOTRE_PROJECT_ID.firebaseapp.com',
       storageBucket: 'VOTRE_PROJECT_ID.appspot.com',
     );

     static const FirebaseOptions android = FirebaseOptions(
       apiKey: 'VOTRE_ANDROID_API_KEY',
       appId: 'VOTRE_ANDROID_APP_ID',
       messagingSenderId: 'VOTRE_SENDER_ID',
       projectId: 'VOTRE_PROJECT_ID',
       storageBucket: 'VOTRE_PROJECT_ID.appspot.com',
     );

     static const FirebaseOptions ios = FirebaseOptions(
       apiKey: 'VOTRE_IOS_API_KEY',
       appId: 'VOTRE_IOS_APP_ID',
       messagingSenderId: 'VOTRE_SENDER_ID',
       projectId: 'VOTRE_PROJECT_ID',
       storageBucket: 'VOTRE_PROJECT_ID.appspot.com',
       iosClientId: 'VOTRE_IOS_CLIENT_ID',
       iosBundleId: 'com.supertache.supertache',
     );
   }
   ```

6. Modifiez lib/main.dart pour importer ce fichier :

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


APRÈS L'INSTALLATION DE FIREBASE CLI
═══════════════════════════════════════════════════════════════════════════════

Une fois Firebase CLI installé, exécutez :

1. Se connecter à Firebase :
   
   firebase login

2. Configurer FlutterFire :
   
   cd /Users/jorisdeguet/Documents/GitHub/jorisdeguet.github.io/supertache
   flutterfire configure

3. Suivre les instructions interactives :
   • Sélectionner ou créer un projet Firebase
   • Choisir les plateformes (iOS, Android, Web)
   • Confirmer la configuration

4. Le fichier lib/firebase_options.dart sera créé automatiquement


CONFIGURER LES RÈGLES FIRESTORE
═══════════════════════════════════════════════════════════════════════════════

Dans Firebase Console > Firestore Database > Règles, copiez ceci :

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


TESTER L'APPLICATION
═══════════════════════════════════════════════════════════════════════════════

Une fois Firebase configuré :

flutter run -d chrome


DÉPANNAGE
═══════════════════════════════════════════════════════════════════════════════

Erreur "firebase: command not found" :
→ Firebase CLI n'est pas installé ou pas dans le PATH

Erreur npm EACCES :
→ Exécutez: sudo chown -R $(whoami) ~/.npm

Firebase CLI installé mais flutterfire ne le trouve pas :
→ Redémarrez votre terminal

Autres erreurs :
→ Consultez FIREBASE_SETUP.md pour plus de détails

═══════════════════════════════════════════════════════════════════════════════
