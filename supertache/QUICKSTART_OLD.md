# Guide de démarrage rapide - SuperTâche

## Prérequis

- Flutter SDK installé (version 3.0+)
- Un compte Google pour Firebase
- Un éditeur de code (VS Code, Android Studio, etc.)

## Installation et configuration

### 1. Vérifier l'installation Flutter

```bash
flutter doctor
```

Assurez-vous que tout est ✓ (ou au moins Flutter et le SDK de votre plateforme cible).

### 2. Installer les dépendances

```bash
cd /Users/jorisdeguet/Documents/GitHub/jorisdeguet.github.io/supertache
flutter pub get
```

### 3. Configurer Firebase

#### Option A : Configuration automatique (recommandé)

```bash
# Installer FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurer le projet
flutterfire configure
```

Suivez les instructions interactives pour :
- Vous connecter à votre compte Google
- Créer ou sélectionner un projet Firebase
- Générer la configuration pour vos plateformes

#### Option B : Configuration manuelle

Consultez le fichier `FIREBASE_SETUP.md` pour les instructions détaillées.

### 4. Activer les services Firebase

Dans la [Console Firebase](https://console.firebase.google.com/) :

1. **Authentication** : Activez Email/Password
2. **Firestore** : Créez une base de données
3. Copiez les règles de sécurité depuis `FIREBASE_SETUP.md`

### 5. Lancer l'application

```bash
# Pour Web
flutter run -d chrome

# Pour Android
flutter run -d android

# Pour iOS (macOS uniquement)
flutter run -d ios
```

## Utilisation

### Premier lancement

1. **Créer un compte**
   - Cliquez sur "Créer un compte"
   - Remplissez vos informations
   - Connectez-vous

2. **Créer une session**
   - Cliquez sur "Créer une session"
   - Entrez le nom (ex: "Automne 2024")
   - Sélectionnez le type (Automne/Hiver) et l'année
   - Cliquez sur la session créée pour la sélectionner

3. **Importer des groupes**
   - Allez dans l'onglet "Groupes"
   - Cliquez sur "Importer des groupes"
   - Collez vos données au format :
     ```
     420-SN1-EM, Programmation I, 35, 1.5
     420-SN2-EM, Programmation II, 30, 1.5
     ```
   - Prévisualisez et importez

4. **Gérer votre tâche**
   - Allez dans l'onglet "Tâches"
   - Cliquez sur "Modifier" dans "Ma tâche"
   - Sélectionnez vos groupes
   - La CI totale se calcule automatiquement
   - Enregistrez

## Format des données

### Import de groupes

Format par ligne : `Numéro, Nom, Nombre d'étudiants, CI`

Exemple :
```
420-SN1-EM, Programmation I, 35, 1.5
420-SN2-EM, Programmation II, 30, 1.5
420-BD1-EM, Bases de données, 32, 1.2
420-WEB-EM, Développement Web, 28, 1.3
```

Séparateurs acceptés :
- Virgules : `,`
- Tabulations : `\t`
- Espaces multiples : `  `

### Numéro de cours

Format strict : `420-XXX-EM`
- `420` : Préfixe fixe
- `XXX` : 3 caractères alphanumériques
- `EM` : Suffixe fixe

Exemples valides :
- `420-SN1-EM`
- `420-BD2-EM`
- `420-A1B-EM`

## Structure de l'application

```
┌─────────────────────────────────────┐
│         SuperTâche                  │
├─────────────────────────────────────┤
│  Sessions    Groupes    Tâches      │
├─────────────────────────────────────┤
│                                     │
│  Créer/Sélectionner une session    │
│  ↓                                  │
│  Importer des groupes               │
│  ↓                                  │
│  Affecter des groupes à ma tâche    │
│  ↓                                  │
│  Voir la CI totale                  │
│                                     │
└─────────────────────────────────────┘
```

## Dépannage

### L'application ne compile pas

```bash
flutter clean
flutter pub get
flutter run
```

### Firebase n'est pas initialisé

Assurez-vous d'avoir exécuté :
```bash
flutterfire configure
```

### Erreurs d'authentification

Vérifiez que Email/Password est activé dans Firebase Console → Authentication → Sign-in method

### Impossible de lire/écrire dans Firestore

Vérifiez vos règles de sécurité dans Firebase Console → Firestore Database → Règles

### L'import de groupes ne fonctionne pas

Vérifiez le format de vos données :
- Une ligne par groupe
- Séparateurs corrects
- Format de numéro : `420-XXX-EM`

## Support

Pour plus d'informations :
- Consultez le `README.md` pour la documentation complète
- Consultez `FIREBASE_SETUP.md` pour la configuration Firebase
- Documentation Flutter : https://docs.flutter.dev/
- Documentation Firebase : https://firebase.google.com/docs
