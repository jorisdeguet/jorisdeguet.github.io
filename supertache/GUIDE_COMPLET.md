# Guide complet - SuperTâche v2.0

## 🎯 Vue d'ensemble des changements

SuperTâche a été refactorée pour gérer les tâches avec import CSV et gestion simplifiée des professeurs.

## 📋 Nouveau système de tâches

### Concept

Une **tâche complète** contient :
- Nom de la tâche
- Session associée
- Liste des enseignants (par emails)
- Liste des groupes-cours

Chaque **groupe** contient :
- Nom du cours
- Numéro du groupe (ex: 1010, 1020)
- Nombre d'étudiants
- Heures de théorie
- Heures de pratique
- CI calculée automatiquement

### Format CSV pour l'import

```
Programmation I, 1010, 35, 45, 30
Programmation II, 1020, 30, 45, 30
Bases de données, 1010, 32, 30, 45
```

**Format** : `Cours, NuméroGroupe, NbÉtudiants, HeuresThéorie, HeuresPratique`

### Import des enseignants

Vous pouvez coller une liste d'emails dans un champ texte :
```
prof1@exemple.com
prof2@exemple.com, prof3@exemple.com
prof4@exemple.com; prof5@exemple.com
```

L'analyseur extrait automatiquement tous les emails valides.

## 🔐 Authentification

**Méthode** : Email + Mot de passe (Firebase Auth classique)

### Connexion
- Email
- Mot de passe
- Option "Mot de passe oublié"

### Inscription
- Prénom
- Nom
- Email
- Mot de passe
- Confirmation du mot de passe

Le profil enseignant est créé automatiquement lors de l'inscription.

## 📁 Structure des données

### Modèles

#### Groupe
```dart
{
  id: String
  cours: String
  numeroGroupe: String
  nombreEtudiants: int
  heuresTheorie: double
  heuresPratique: double
  tacheId: String
  ci: double (calculé)
}
```

#### TacheComplete
```dart
{
  id: String
  sessionId: String
  nom: String
  dateCreation: DateTime
  enseignantEmails: List<String>
  enseignantIds: List<String> (résolu automatiquement)
  groupeIds: List<String>
}
```

#### Session
```dart
{
  id: String
  name: String
  type: SessionType (automne/hiver)
  year: int
  startDate: DateTime
  endDate: DateTime
}
```

#### Enseignant
```dart
{
  id: String
  nom: String
  prenom: String
  email: String
  photoUrl: String?
}
```

## 🎨 Écrans principaux

### 1. Écran de connexion (LoginScreen)
- Email + mot de passe
- Lien vers inscription
- Réinitialisation du mot de passe

### 2. Écran d'inscription (SignupScreen)
- Prénom, nom, email, mot de passe
- Création automatique du profil enseignant

### 3. Écran d'accueil (HomeScreen)
- Navigation entre Sessions et Tâches
- Sélection de session active
- Déconnexion

### 4. Écran des tâches (TachesListScreen)
- Affiche "Mes tâches" (où l'utilisateur est inclus)
- Affiche toutes les tâches de la session
- Bouton pour créer une nouvelle tâche

### 5. Créer une tâche (CreateTacheScreen)
- Nom de la tâche
- Import d'enseignants (par emails)
- Import de groupes (CSV ou manuel)
- Prévisualisation avant création

### 6. Voir une tâche (ViewTacheScreen)
- Détails de la tâche
- Liste des enseignants
- Liste des groupes avec CI
- Statistiques (nb groupes, étudiants, CI totale)
- Suppression de la tâche

## 🔄 Flux utilisateur

### Créer une tâche

```
1. Sélectionner une session
2. Aller dans l'onglet "Tâches"
3. Cliquer sur le bouton "+"
4. Entrer le nom de la tâche
5. Coller la liste des emails des enseignants
6. Coller le CSV des groupes OU ajouter manuellement
7. Cliquer sur "Analyser CSV" pour prévisualiser
8. Cliquer sur "Créer"
```

### Voir ses tâches

```
1. Sélectionner une session
2. Aller dans l'onglet "Tâches"
3. Les tâches où l'utilisateur est inclus apparaissent en premier
4. Cliquer sur une tâche pour voir les détails
```

## 📊 Calcul de la CI

**Formule actuelle** :
```dart
CI = ((heuresThéorie * 1.0) + (heuresPratique * 1.2)) / 15
```

Vous pouvez ajuster cette formule dans `lib/models/groupe.dart`, propriété `ci`.

## 🗄️ Collections Firestore

### taches_completes
```
{
  id: string
  sessionId: string
  nom: string
  dateCreation: timestamp
  enseignantEmails: array<string>
  enseignantIds: array<string>
  groupeIds: array<string>
}
```

### groupes
```
{
  id: string
  cours: string
  numeroGroupe: string
  nombreEtudiants: number
  heuresTheorie: number
  heuresPratique: number
  tacheId: string
}
```

### enseignants
```
{
  id: string (uid Firebase Auth)
  nom: string
  prenom: string
  email: string
  photoUrl: string?
}
```

### sessions
```
{
  id: string
  name: string
  type: string
  year: number
  startDate: timestamp
  endDate: timestamp
}
```

## 🔒 Règles Firestore recommandées

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Sessions - lecture/écriture pour authentifiés
    match /sessions/{sessionId} {
      allow read, write: if request.auth != null;
    }
    
    // Enseignants
    match /enseignants/{enseignantId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == enseignantId;
    }
    
    // Groupes - lecture/écriture pour authentifiés
    match /groupes/{groupeId} {
      allow read, write: if request.auth != null;
    }
    
    // Tâches complètes
    match /taches_completes/{tacheId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

## 🚀 Commandes utiles

### Lancer l'application
```bash
flutter run -d chrome
```

### Analyser le code
```bash
flutter analyze
```

### Nettoyer et reconstruire
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

## 📝 Exemples de données

### CSV de groupes
```csv
Programmation I, 1010, 35, 45, 30
Programmation II, 1020, 30, 45, 30
Programmation III, 1030, 28, 45, 30
Bases de données I, 1010, 32, 30, 45
Bases de données II, 1020, 28, 30, 45
Développement Web, 1010, 30, 30, 45
Développement mobile, 1020, 25, 30, 45
Réseaux, 1010, 27, 45, 15
Sécurité, 1020, 24, 30, 30
Projet final, 1010, 20, 15, 60
```

### Liste d'enseignants
```
jean.dupont@college.qc.ca
marie.martin@college.qc.ca
pierre.bernard@college.qc.ca
sophie.dubois@college.qc.ca
```

## 🎯 Fonctionnalités clés

### ✅ Implémenté

- Authentification email/mot de passe
- Création de sessions
- Création de tâches avec nom personnalisé
- Import CSV de groupes
- Ajout manuel de groupes
- Parser intelligent d'emails
- Calcul automatique de la CI
- Association automatique des enseignants
- Vue "Mes tâches" filtrée
- Vue détaillée d'une tâche
- Suppression de tâches (avec groupes)
- Statistiques par tâche

### 🔮 Améliorations futures possibles

- Export de tâches en PDF
- Modification de tâches existantes
- Duplication de tâches
- Historique des modifications
- Notifications par email
- Import Excel natif
- Graphiques de répartition de la CI
- Comparaison entre sessions
- Commentaires sur les tâches
- Gestion des remplacements

## 📞 Support

Pour toute question :
1. Consultez ce guide
2. Vérifiez les logs avec `flutter run -v`
3. Consultez la documentation Flutter/Firebase

## 🎉 Démarrage rapide

```bash
# 1. S'assurer que Firebase est configuré
cd /path/to/supertache
flutterfire configure  # Si pas déjà fait

# 2. Activer Email/Password dans Firebase Console
# https://console.firebase.google.com/project/supertache-36df7/authentication/providers

# 3. Lancer l'application
flutter run -d chrome

# 4. Créer un compte enseignant
# 5. Créer une session
# 6. Créer une tâche avec CSV
```

Voilà ! Vous êtes prêt à gérer vos tâches d'enseignement.
