# Système d'Algorithme Génétique et Vote de Condorcet

## Vue d'ensemble

Le système implémente un algorithme génétique pour générer automatiquement des répartitions optimales de groupes-cours aux enseignants, en tenant compte de leurs préférences et des contraintes de CI (Charge Individuelle). Les enseignants peuvent ensuite voter sur les solutions proposées via un système de vote préférentiel analysé avec la méthode de Condorcet.

## Composants créés

### 1. Modèles

#### `EnseignantPreferences` (`lib/models/enseignant_preferences.dart`)
Stocke les préférences d'un enseignant :
- **coursSouhaites**: Liste des codes de cours désirés (ex: ["420-1B3", "420-1C5"])
- **coursEvites**: Liste des codes de cours à éviter
- **colleguesSouhaites**: Liste des emails des collègues avec qui travailler
- **colleguesEvites**: Liste des emails des collègues à éviter
- **ciMin/ciMax**: Plage de CI préférée (optionnel, utilise celle de la tâche par défaut)

#### `TacheVote` et `CondorcetResult` (`lib/models/tache_vote.dart`)
- **TacheVote**: Vote préférentiel d'un enseignant (liste ordonnée de tâches)
- **CondorcetResult**: Résultat de l'analyse de Condorcet avec gagnant potentiel

### 2. Services

#### `GeneticAlgorithmService` (`lib/services/genetic_algorithm_service.dart`)
Service principal pour générer des répartitions optimales.

**Paramètres de l'algorithme** :
- `populationSize`: 100 (taille de la population)
- `maxGenerations`: 500 (nombre de générations max)
- `mutationRate`: 0.3 (probabilité de mutation)
- `crossoverRate`: 0.7 (probabilité de croisement)
- `eliteCount`: 10 (nombre d'élites préservés)

**Fonction de fitness** :
La fitness évalue chaque solution selon plusieurs critères :

1. **Score CI** (30 points par enseignant dans la plage cible)
   - Si `ciMin ≤ CI ≤ ciMax`: +30 points
   - Sinon: -5 points par unité de CI hors plage

2. **Préférences de cours**
   - Tous cours souhaités, aucun évité: +10 points
   - Aucun cours souhaité, que des évités: -100 points
   - Mix: 0 point

3. **Préférences de collègues**
   - Tous collègues souhaités, aucun évité: +1 point
   - Aucun collègue souhaité, que des évités: -5 points
   - Mix: 0 point

4. **Pénalité groupes non alloués**
   - -50 points par groupe non alloué

**Opérations génétiques** :

1. **Mutation** (2 types) :
   - **Déplacement**: Déplacer un groupe d'un enseignant à un autre
   - **Transposition**: Échange circulaire entre 3 enseignants (E1→E2, E2→E3, E3→E1)

2. **Crossover**: Combinaison aléatoire des allocations de deux solutions parentes

3. **Sélection**: Tournoi (taille 3) - les 3 meilleures solutions combattent

4. **Élitisme**: Conservation des 10 meilleures solutions à chaque génération

#### `CondorcetVotingService` (`lib/services/condorcet_voting_service.dart`)
Service d'analyse des votes préférentiels.

**Méthode de Condorcet** :
- Un gagnant de Condorcet bat toutes les autres options en duels directs
- Construit une matrice de comparaisons paires
- Détermine si un gagnant existe

**Méthode de Borda (fallback)** :
- Si pas de gagnant de Condorcet (paradoxe de Condorcet)
- Score: (n-1) points pour le 1er choix, (n-2) pour le 2ème, etc.
- La tâche avec le meilleur score total gagne

### 3. Modifications au modèle Tache

Ajout de deux champs au modèle `Tache` :
- **ciMin**: CI minimale acceptée (défaut: 38.0)
- **ciMax**: CI maximale acceptée (défaut: 46.0)

Ces valeurs définissent la plage cible pour l'algorithme génétique.

## Utilisation

### Générer des solutions optimales

```dart
final geneticAlgo = GeneticAlgorithmService();

// Préparer les préférences
final preferences = <String, EnseignantPreferences>{
  'enseignant1_id': EnseignantPreferences(
    enseignantId: 'enseignant1_id',
    enseignantEmail: 'prof1@college.ca',
    coursSouhaites: ['420-1B3', '420-1C5'],
    coursEvites: ['420-3N5'],
    colleguesSouhaites: ['prof2@college.ca'],
    colleguesEvites: ['prof3@college.ca'],
  ),
  // ... autres enseignants
};

// Générer 5 meilleures solutions
final solutions = await geneticAlgo.generateSolutions(
  groupes: tousLesGroupes,
  enseignants: tousLesEnseignants,
  preferences: preferences,
  ciMin: 38.0,
  ciMax: 46.0,
  nbSolutionsFinales: 5,
);

// Convertir en répartitions
for (int i = 0; i < solutions.length; i++) {
  final repartition = solutions[i].toRepartition(
    'repartition_${i}_id',
    tacheId,
  );
  // Sauvegarder dans Firebase
}
```

### Analyser les votes

```dart
final votingService = CondorcetVotingService();

// Collecter les votes des enseignants
final votes = [
  TacheVote(
    enseignantId: 'ens1_id',
    enseignantEmail: 'prof1@college.ca',
    tacheGenerationId: 'generation_1',
    tachesOrdonnees: ['tache_A', 'tache_B', 'tache_C'], // Du meilleur au pire
    dateVote: DateTime.now(),
  ),
  // ... autres votes
];

// Analyser
final resultat = votingService.analyzeComplet(
  votes,
  ['tache_A', 'tache_B', 'tache_C', 'tache_D', 'tache_E'],
);

print('Méthode utilisée: ${resultat['method']}');
print('Gagnant recommandé: ${resultat['recommendedWinner']}');

if (resultat['method'] == 'Condorcet') {
  print('Gagnant de Condorcet trouvé!');
} else {
  print('Pas de gagnant de Condorcet, utilisation de Borda');
  print('Scores Borda: ${resultat['bordaScores']}');
}
```

## Workflow complet

1. **Configuration de la tâche**
   - Créer une tâche avec ciMin et ciMax
   - Les enseignants configurent leurs préférences

2. **Génération automatique**
   - Lancer l'algorithme génétique
   - Obtenir 5-10 solutions optimales
   - Sauvegarder comme répartitions automatiques

3. **Vote des enseignants**
   - Présenter les solutions aux enseignants
   - Chaque enseignant ordonne les solutions par préférence
   - Enregistrer les votes

4. **Analyse et sélection**
   - Analyser avec Condorcet
   - Si gagnant trouvé: utiliser cette solution
   - Sinon: utiliser le gagnant de Borda
   - Marquer la solution gagnante comme validée

5. **Ajustements manuels (optionnel)**
   - Les coordinateurs peuvent affiner manuellement
   - Modifications enregistrées comme nouvelles versions

## Prochaines étapes (UI à créer)

1. **Écran de configuration des préférences enseignant**
   - Sélection des cours souhaités/évités
   - Sélection des collègues souhaités/évités
   - Configuration CI personnalisée

2. **Écran de génération automatique**
   - Bouton "Générer des répartitions automatiques"
   - Barre de progression
   - Affichage des meilleures solutions

3. **Écran de vote**
   - Interface drag-and-drop pour ordonner les solutions
   - Visualisation de sa propre répartition dans chaque solution
   - Comparaison côte-à-côte

4. **Écran de résultats**
   - Affichage du gagnant (Condorcet ou Borda)
   - Matrice de comparaisons
   - Statistiques sur les votes

## Points techniques importants

- L'algorithme utilise un cache de fitness pour éviter les recalculs
- Les mutations garantissent qu'aucun groupe n'est dupliqué ou perdu
- Le crossover inclut une étape de réparation pour maintenir la validité
- L'élitisme assure que les meilleures solutions ne sont jamais perdues
- La méthode de Borda sert de fallback robuste en cas de paradoxe de Condorcet
