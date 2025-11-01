# Guide des Interfaces Utilisateur - Algorithme Génétique et Vote

## Vue d'ensemble

4 écrans ont été créés pour supporter le workflow complet de génération automatique de répartitions et de vote des enseignants.

## 1. Écran de Préférences de l'Enseignant
**Fichier:** `lib/screens/preferences/enseignant_preferences_screen.dart`

### Fonctionnalités
- Configuration des cours souhaités et à éviter
- Configuration des collègues préférés et à éviter
- Configuration de la plage CI personnalisée (optionnel)
- Sauvegarde des préférences pour l'algorithme

### Interface
- **Cours souhaités**: Champ texte + liste de chips (ex: 420-1B3, 420-1C5)
- **Cours à éviter**: Champ texte + liste de chips
- **Collègues préférés**: Champ email + liste de chips
- **Collègues à éviter**: Champ email + liste de chips
- **Plage CI**: Deux champs numériques (min/max)

### Utilisation
```dart
Navigator.pushNamed(context, '/preferences');
```

### TODO
- Implémenter `saveEnseignantPreferences()` dans FirestoreService
- Implémenter `getEnseignantPreferences()` dans FirestoreService
- Ajouter validation pour éviter les conflits (même cours souhaité ET évité)

---

## 2. Écran de Génération Automatique
**Fichier:** `lib/screens/repartitions/generate_repartitions_screen.dart`

### Fonctionnalités
- Affichage des statistiques de la tâche (enseignants, groupes, plage CI)
- Configuration des paramètres de l'algorithme :
  - Nombre de solutions à générer (3-10)
  - Taille de la population (50-200)
  - Nombre de générations max (100-1000)
- Lancement de l'algorithme génétique
- Affichage de la progression
- Liste des répartitions générées

### Interface
- Statistiques en cartes (enseignants, groupes, plage CI)
- Sliders pour ajuster les paramètres
- Bouton "Générer les répartitions"
- Indicateur de progression pendant la génération
- Liste des solutions générées avec liens

### Utilisation
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => GenerateRepartitionsScreen(tacheId: tacheId),
  ),
);
```

### Workflow
1. Charger la tâche, groupes et enseignants
2. Afficher les statistiques
3. L'utilisateur ajuste les paramètres
4. Clic sur "Générer"
5. L'algorithme s'exécute (affiche progression)
6. Les solutions sont sauvegardées dans Firestore
7. Liste affichée avec liens vers les détails

### Notes techniques
- Utilise `GeneticAlgorithmService.generateSolutions()`
- Les solutions sont marquées comme `estAutomatique = true`
- Chaque solution est sauvegardée avec un ID unique

---

## 3. Écran de Vote
**Fichier:** `lib/screens/voting/vote_repartitions_screen.dart`

### Fonctionnalités
- Affichage de toutes les répartitions générées
- Interface de réorganisation par glisser-déposer
- Visualisation de la CI personnelle pour chaque répartition
- Badges visuels pour le classement (1er choix, dernier choix, etc.)
- Soumission du vote

### Interface
- Instructions en haut (fond bleu)
- Liste réorganisable (`ReorderableListView`)
- Chaque carte montre :
  - Position actuelle (badge coloré)
  - CI personnelle de l'enseignant
  - Bouton pour voir les détails
- Bouton "Soumettre mon vote" en bas

### Utilisation
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => VoteRepartitionsScreen(
      tacheId: tacheId,
      generationId: generationId,
    ),
  ),
);
```

### Workflow
1. Charger les répartitions automatiques
2. Initialiser l'ordre (par défaut : ordre de création)
3. L'enseignant réorganise en glissant les cartes
4. Visualise sa CI pour chaque option
5. Soumet son vote
6. Vote sauvegardé dans Firestore

### Codes de couleur
- **Vert** : 1er choix
- **Orange** : Choix intermédiaires
- **Rouge** : Dernier choix

### TODO
- Implémenter `saveTacheVote()` dans FirestoreService
- Empêcher de voter deux fois (vérifier si vote existe)
- Afficher un message si déjà voté

---

## 4. Écran des Résultats du Vote
**Fichier:** `lib/screens/voting/vote_results_screen.dart`

### Fonctionnalités
- Affichage des statistiques du vote (nb votes, nb répartitions)
- Affichage du gagnant (Condorcet ou Borda)
- Classement de toutes les répartitions
- Matrice des duels (pour Condorcet)
- Explication de la méthode utilisée

### Interface
- **En-tête** : Statistiques (votes, répartitions, méthode)
- **Carte gagnante** : Fond doré, icône trophée
- **Classement** : Liste de toutes les répartitions avec scores
- **Explication** : Carte bleue expliquant la méthode
- **Matrice** (Condorcet) : Table des comparaisons paires

### Utilisation
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => VoteResultsScreen(
      tacheId: tacheId,
      generationId: generationId,
    ),
  ),
);
```

### Workflow
1. Charger tous les votes de la génération
2. Appeler `CondorcetVotingService.analyzeComplet()`
3. Afficher le gagnant :
   - Si gagnant de Condorcet existe : afficher avec badge spécial
   - Sinon : afficher gagnant de Borda
4. Afficher le classement complet
5. Afficher la matrice (si Condorcet)

### Éléments visuels
- **Gagnant** : Fond doré, trophée, bouton "Voir"
- **Classement** : Scores Condorcet (victoires) ou Borda (points)
- **Matrice** : Table avec scores en vert (gagne) ou rouge (perd)

### TODO
- Implémenter `getTacheVotes()` dans FirestoreService
- Ajouter filtres pour voir seulement ses propres votes
- Exporter les résultats en PDF

---

## Intégration dans l'application

### Routes à ajouter
```dart
// Dans le router principal
routes: {
  '/preferences': (context) => const EnseignantPreferencesScreen(),
  '/generate-repartitions': (context) => GenerateRepartitionsScreen(
    tacheId: /* passer en argument */,
  ),
  '/vote-repartitions': (context) => VoteRepartitionsScreen(
    tacheId: /* passer en argument */,
    generationId: /* passer en argument */,
  ),
  '/vote-results': (context) => VoteResultsScreen(
    tacheId: /* passer en argument */,
    generationId: /* passer en argument */,
  ),
}
```

### Points d'accès suggérés

#### Dans le menu de navigation (AppDrawer)
```dart
ListTile(
  leading: const Icon(Icons.settings),
  title: const Text('Mes préférences'),
  onTap: () => Navigator.pushNamed(context, '/preferences'),
),
```

#### Dans l'écran de détails de tâche
```dart
// Bouton pour générer
ElevatedButton.icon(
  icon: const Icon(Icons.auto_awesome),
  label: const Text('Générer automatiquement'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GenerateRepartitionsScreen(tacheId: tache.id),
    ),
  ),
),
```

#### Dans la liste des répartitions
```dart
// Bouton pour voter
if (hasAutoRepartitions) {
  ElevatedButton.icon(
    icon: const Icon(Icons.how_to_vote),
    label: const Text('Voter pour une répartition'),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteRepartitionsScreen(
          tacheId: tache.id,
          generationId: currentGenerationId,
        ),
      ),
    ),
  ),
}

// Bouton pour voir les résultats
ElevatedButton.icon(
  icon: const Icon(Icons.bar_chart),
  label: const Text('Voir les résultats'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VoteResultsScreen(
        tacheId: tache.id,
        generationId: currentGenerationId,
      ),
    ),
  ),
),
```

---

## Modifications Firebase nécessaires

### Collection `enseignant_preferences`
```javascript
{
  enseignantId: string,
  enseignantEmail: string,
  coursSouhaites: string[],
  coursEvites: string[],
  colleguesSouhaites: string[],
  colleguesEvites: string[],
  ciMin: number | null,
  ciMax: number | null,
  dateModification: timestamp
}
```

### Collection `tache_votes`
```javascript
{
  enseignantId: string,
  enseignantEmail: string,
  tacheGenerationId: string,
  tachesOrdonnees: string[], // IDs des répartitions ordonnées
  dateVote: timestamp
}
```

### Index Firestore requis
- `enseignant_preferences`: index sur `enseignantId`
- `tache_votes`: index composé sur `tacheGenerationId` + `enseignantId`

---

## Flux de travail complet

1. **Configuration** (une fois)
   - Enseignants vont dans "Mes préférences"
   - Configurent cours et collègues

2. **Génération** (par le coordinateur)
   - Ouvre la tâche
   - Clique "Générer automatiquement"
   - Ajuste les paramètres si nécessaire
   - Lance la génération
   - 5+ répartitions créées

3. **Vote** (par les enseignants)
   - Notification envoyée aux enseignants
   - Chacun ouvre l'écran de vote
   - Réorganise les options par préférence
   - Soumet le vote

4. **Résultats** (visible par tous)
   - Affichage du gagnant de Condorcet (ou Borda)
   - Classement complet
   - Coordinateur peut valider la solution gagnante

5. **Finalisation** (par le coordinateur)
   - Marque la répartition gagnante comme "approuvée"
   - Notifie les enseignants
   - Possibilité d'ajustements manuels si nécessaire

---

## Prochaines améliorations possibles

1. **Notifications**
   - Email quand nouvelles répartitions générées
   - Rappel pour voter
   - Notification des résultats

2. **Historique**
   - Voir les générations précédentes
   - Comparer avec les années antérieures

3. **Export**
   - PDF des résultats
   - CSV de la répartition finale
   - Rapport pour la direction

4. **Analytics**
   - Statistiques sur les préférences
   - Taux de satisfaction global
   - Évolution des CI dans le temps
