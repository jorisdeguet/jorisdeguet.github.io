# SuperTâche - Application de gestion des tâches d'enseignement

## 📋 Vue d'ensemble

SuperTâche est une application Flutter complète pour la gestion des tâches d'enseignement dans un établissement scolaire. Elle permet de gérer les sessions académiques, les groupes de cours, et l'affectation des enseignants avec calcul automatique de la charge individuelle (CI).

## ✨ Fonctionnalités principales

### 🔐 Authentification
- Inscription et connexion sécurisées avec Firebase Authentication
- Gestion des profils enseignants
- Système de réinitialisation de mot de passe

### 📅 Gestion des sessions
- Création de sessions d'automne et d'hiver
- Association automatique des périodes (dates de début/fin)
- Vue d'ensemble de toutes les sessions

### 👥 Gestion des groupes
- Import facile par copier-coller
- Format flexible : CSV, tabulations ou espaces multiples
- Format de numéro de cours standardisé (420-XXX-EM)
- Affichage détaillé avec nombre d'étudiants et CI
- Ajout manuel de groupes individuels
- Suppression de groupes

### 📊 Gestion des tâches
- Affectation des groupes à sa propre tâche
- Calcul automatique de la CI totale
- Vue d'ensemble de toutes les tâches des enseignants
- Statistiques visuelles (nombre de groupes, CI totale)
- Mise en évidence de sa propre tâche

## 🏗️ Architecture

### Modèles de données
- **Session** : Périodes académiques (automne/hiver)
- **Enseignant** : Profils des utilisateurs
- **Groupe** : Cours avec numéro, nom, étudiants, et CI
- **TacheIndividuelle** : Affectation d'un enseignant à des groupes
- **TacheComplete** : Collection de toutes les tâches d'une session

### Services
- **AuthService** : Gestion de l'authentification Firebase
- **FirestoreService** : Opérations CRUD sur Firestore

### Écrans
- **Auth** : Connexion et inscription
- **Sessions** : Création et sélection de sessions
- **Groupes** : Gestion et import de groupes
- **Tâches** : Affectation et visualisation des tâches

## 🛠️ Technologies utilisées

- **Flutter** : Framework UI multiplateforme
- **Firebase Auth** : Authentification des utilisateurs
- **Cloud Firestore** : Base de données NoSQL temps réel
- **Provider** : Gestion d'état
- **Material Design 3** : Interface moderne et responsive

## 📦 Dépendances

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.2.0
  firebase_auth: ^6.1.1
  cloud_firestore: ^6.0.3
  provider: ^6.1.5+1
```

## 🚀 Démarrage rapide

1. **Installation des dépendances**
   ```bash
   flutter pub get
   ```

2. **Configuration Firebase**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

3. **Activation des services** (dans Firebase Console)
   - Firebase Authentication (Email/Password)
   - Cloud Firestore

4. **Lancement de l'application**
   ```bash
   flutter run -d chrome  # Pour Web
   ```

Consultez `QUICKSTART.md` pour plus de détails.

## 📄 Documentation

- **README.md** : Documentation complète du projet
- **QUICKSTART.md** : Guide de démarrage rapide
- **FIREBASE_SETUP.md** : Configuration détaillée de Firebase
- **SAMPLE_DATA.md** : Données d'exemple pour tester l'application

## 🎯 Cas d'utilisation

### Scénario typique

1. **Admin/Coordinateur** crée une session (ex: Automne 2024)
2. **Admin** importe tous les groupes de la session
3. **Enseignants** se connectent et sélectionnent la session
4. **Enseignants** affectent leurs groupes à leur tâche
5. **Tous** peuvent voir la répartition complète des tâches

### Format d'import des groupes

```
420-SN1-EM, Programmation I, 35, 1.5
420-SN2-EM, Programmation II, 30, 1.5
420-BD1-EM, Bases de données I, 32, 1.2
```

## 🔒 Sécurité

Les règles Firestore assurent que :
- Seuls les utilisateurs authentifiés peuvent accéder aux données
- Les enseignants ne peuvent modifier que leur propre profil
- Toutes les opérations sont tracées via Firebase

## 🎨 Interface utilisateur

- Design Material 3 moderne
- Navigation par onglets intuitive
- Cartes et listes pour une meilleure lisibilité
- Feedback visuel (couleurs, icônes)
- Responsive pour mobile, tablette et web

## 📊 Calcul de la CI

La CI (Charge Individuelle) totale est calculée automatiquement en sommant les CI de tous les groupes affectés à un enseignant. Cela permet de :
- Équilibrer la charge de travail entre enseignants
- Respecter les limites de CI par enseignant
- Avoir une vue d'ensemble de la répartition

## 🔄 Prochaines améliorations possibles

- [ ] Export PDF des tâches
- [ ] Statistiques avancées
- [ ] Notifications push
- [ ] Historique des modifications
- [ ] Import Excel/CSV natif
- [ ] Gestion des remplacements
- [ ] Commentaires sur les tâches
- [ ] Validation par administrateur
- [ ] Rapport de charge par département
- [ ] Calendrier intégré

## 📝 Structure du code

```
lib/
├── main.dart                               # Point d'entrée
├── models/                                 # Modèles de données
│   ├── enseignant.dart                     # 35 lignes
│   ├── groupe.dart                         # 47 lignes
│   ├── session.dart                        # 43 lignes
│   ├── tache_complete.dart                 # 38 lignes
│   └── tache_individuelle.dart             # 35 lignes
├── screens/                                # Interface utilisateur
│   ├── auth/
│   │   ├── login_screen.dart               # 140 lignes
│   │   └── signup_screen.dart              # 179 lignes
│   ├── groupes/
│   │   ├── groupes_screen.dart             # 223 lignes
│   │   └── import_groupes_screen.dart      # 203 lignes
│   ├── sessions/
│   │   └── sessions_screen.dart            # 176 lignes
│   ├── taches/
│   │   ├── affecter_groupes_screen.dart    # 221 lignes
│   │   └── taches_screen.dart              # 258 lignes
│   └── home_screen.dart                    # 82 lignes
└── services/                               # Logique métier
    ├── auth_service.dart                   # 59 lignes
    └── firestore_service.dart              # 135 lignes

Total : ~16 fichiers, ~1,873 lignes de code
```

## 🤝 Contribution

Ce projet a été créé pour faciliter la gestion des tâches d'enseignement. N'hésitez pas à l'adapter à vos besoins spécifiques.

## 📧 Support

Pour toute question ou problème :
1. Consultez la documentation dans les fichiers .md
2. Vérifiez les logs avec `flutter run -v`
3. Consultez la documentation Flutter/Firebase

## 📜 Licence

Ce projet est un outil interne. Adaptez selon vos besoins.

---

**Créé avec** ❤️ **et Flutter**
