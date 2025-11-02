import 'dart:math';
import '../models/groupe.dart';
import '../models/enseignant.dart';
import '../models/enseignant_preferences.dart';
import '../models/repartition.dart';
import '../models/tache.dart';
import 'ci_calculator_service.dart';

/// Solution candidate pour l'algorithme génétique
class TacheSolution {
  // Allocation: Map<enseignantId, List<groupeId>>
  final Map<String, List<String>> allocations;
  final List<String> groupesNonAlloues;
  
  double? _fitness; // Cache du score de fitness
  
  TacheSolution({
    required this.allocations,
    required this.groupesNonAlloues,
  });

  double? get fitness => _fitness;
  set fitness(double? value) => _fitness = value;

  /// Crée une copie profonde de la solution
  TacheSolution copy() {
    return TacheSolution(
      allocations: allocations.map((k, v) => MapEntry(k, List<String>.from(v))),
      groupesNonAlloues: List<String>.from(groupesNonAlloues),
    );
  }

  /// Convertit en Repartition
  Repartition toRepartition(String id, String tacheId) {
    return Repartition(
      id: id,
      nom: 'Répartition automatique ${DateTime.now().toIso8601String()}',
      tacheId: tacheId,
      allocations: allocations,
      groupesNonAlloues: groupesNonAlloues,
      estValide: false, // Sera mis à jour après calcul
      dateCreation: DateTime.now(),
      estAutomatique: true,
    );
  }
}

/// Poids des différents critères du score de fitness
class FitnessWeights {
  final double wCiBonus;
  final double wCiPenaltyPerUnit;
  final double wCours2Penalty;
  final double wCours3Penalty;
  final double wCours4PlusPenalty;
  final double wCoursWishBonus;
  final double wCoursAvoidPenalty;
  final double wColWishBonus;
  final double wColAvoidPenalty;
  final double wUnallocatedPenalty;
  const FitnessWeights({
    this.wCiBonus = 30,
    this.wCiPenaltyPerUnit = 5,
    this.wCours2Penalty = -10,
    this.wCours3Penalty = -30,
    this.wCours4PlusPenalty = -100,
    this.wCoursWishBonus = 10,
    this.wCoursAvoidPenalty = -100,
    this.wColWishBonus = 1,
    this.wColAvoidPenalty = -5,
    this.wUnallocatedPenalty = -50,
  });
}

/// Service d'algorithme génétique pour créer des répartitions optimales
class GeneticAlgorithmService {
  final CICalculatorService _ciCalculator = CICalculatorService();
  final Random _random = Random();

  // Paramètres de l'algorithme
  final int populationSize;
  final int maxGenerations;
  final double mutationRate;
  final double crossoverRate;
  final int eliteCount;
  final FitnessWeights weights;

  GeneticAlgorithmService({
    this.populationSize = 100,
    this.maxGenerations = 500,
    this.mutationRate = 0.3,
    this.crossoverRate = 0.7,
    this.eliteCount = 10,
    this.weights = const FitnessWeights(),
  });

  /// Génère des solutions optimales avec callback de progression
  Future<List<TacheSolution>> generateSolutions({
    required List<Groupe> groupes,
    required List<Enseignant> enseignants,
    required Map<String, EnseignantPreferences> preferences,
    double ciMin = 38.0,
    double ciMax = 46.0,
    int nbSolutionsFinales = 5,
    List<TacheSolution>? seedSolutions,
    Function(int generation, List<TacheSolution> topSolutions)? onProgress,
  }) async {
    if (groupes.isEmpty || enseignants.isEmpty) {
      return [];
    }

    // Initialiser la population
    List<TacheSolution> population = [];
    final signatures = <String>{};

    // Ajouter les graines (solutions seed) au début
    if (seedSolutions != null && seedSolutions.isNotEmpty) {
      for (var s in seedSolutions) {
        final c = s.copy();
        _repairSolution(c, s); // s'assurer cohérence
        final sig = _getSignature(c);
        if (!signatures.contains(sig)) {
          population.add(c);
          signatures.add(sig);
          if (population.length >= populationSize) break;
        }
      }
    }

    // Compléter avec population aléatoire
    final needed = populationSize - population.length;
    if (needed > 0) {
      final randomPop = _createInitialPopulation(groupes, enseignants, needed, preferences, ciMin, ciMax);
      for (var s in randomPop) {
        final sig = _getSignature(s);
        if (!signatures.contains(sig)) {
          population.add(s);
          signatures.add(sig);
        }
      }
    }

    // Évolution
    for (int generation = 0; generation < maxGenerations; generation++) {
      // Calculer le fitness de chaque solution
      for (var solution in population) {
        solution.fitness ??= _calculateFitness(
          solution,
          groupes,
          enseignants,
          preferences,
          ciMin,
          ciMax,
        );
      }

      // Trier par fitness (du meilleur au pire)
      population.sort((a, b) => (b.fitness ?? 0).compareTo(a.fitness ?? 0));

      // Callback de progression à chaque génération
      if (onProgress != null) {
        onProgress(generation, population.take(3).toList());
      }

      // Élitisme: garder les meilleures solutions
      final elite = population.take(eliteCount).map((s) => s.copy()).toList();

      // Créer la nouvelle génération
      List<TacheSolution> newPopulation = List.from(elite);

      while (newPopulation.length < populationSize) {
        // Sélection par tournoi
        final parent1 = _tournamentSelection(population);
        final parent2 = _tournamentSelection(population);

        // Crossover
        TacheSolution child;
        if (_random.nextDouble() < crossoverRate) {
          child = _crossover(parent1, parent2, enseignants);
        } else {
          child = parent1.copy();
        }

        // Mutation
        if (_random.nextDouble() < mutationRate) {
          _mutate(child, groupes, enseignants);
        }

        newPopulation.add(child);
      }

      population = newPopulation;

      // Log de progression
      if (generation % 50 == 0) {
        final bestFitness = population.first.fitness ?? 0;
        print('Génération $generation: Meilleur fitness = $bestFitness');
      }
    }

    // Calculer le fitness final pour toutes les solutions
    for (var solution in population) {
      solution.fitness ??= _calculateFitness(
        solution,
        groupes,
        enseignants,
        preferences,
        ciMin,
        ciMax,
      );
    }

    // Trier et retourner les meilleures solutions DIVERSES
    population.sort((a, b) => (b.fitness ?? 0).compareTo(a.fitness ?? 0));
    
    return _selectDiverseSolutions(population, nbSolutionsFinales);
  }

  /// Sélectionne des solutions diverses parmi les meilleures
  List<TacheSolution> _selectDiverseSolutions(
    List<TacheSolution> sortedPopulation,
    int count,
  ) {
    if (sortedPopulation.length <= count) {
      return sortedPopulation;
    }

    final selected = <TacheSolution>[];
    final signatures = <String>{};

    // Toujours prendre la meilleure solution
    selected.add(sortedPopulation.first);
    signatures.add(_getSignature(sortedPopulation.first));

    // Pour les autres, privilégier la diversité
    for (var solution in sortedPopulation.skip(1)) {
      if (selected.length >= count) break;

      final signature = _getSignature(solution);

      // Vérifier si cette solution est suffisamment différente
      bool isDifferent = true;
      for (var existingSignature in signatures) {
        if (_calculateSimilarity(signature, existingSignature) > 0.8) {
          isDifferent = false;
          break;
        }
      }

      if (isDifferent) {
        selected.add(solution);
        signatures.add(signature);
      }
    }

    // Si on n'a pas assez de solutions diverses, prendre les meilleures restantes
    while (selected.length < count && selected.length < sortedPopulation.length) {
      for (var solution in sortedPopulation) {
        if (selected.length >= count) break;
        if (!selected.contains(solution)) {
          selected.add(solution);
        }
      }
    }

    return selected;
  }

  /// Calcule une signature pour une solution
  String _getSignature(TacheSolution solution) {
    final sortedKeys = solution.allocations.keys.toList()..sort();
    final parts = <String>[];

    for (var key in sortedKeys) {
      final groupes = solution.allocations[key]!.toList()..sort();
      parts.add('$key:${groupes.join(',')}');
    }

    return parts.join('|');
  }

  /// Calcule la similarité entre deux signatures (0.0 = différent, 1.0 = identique)
  double _calculateSimilarity(String sig1, String sig2) {
    if (sig1 == sig2) return 1.0;

    final parts1 = sig1.split('|').toSet();
    final parts2 = sig2.split('|').toSet();

    final intersection = parts1.intersection(parts2).length;
    final union = parts1.union(parts2).length;

    return union > 0 ? intersection / union : 0.0;
  }

  /// Crée une population initiale aléatoire
  List<TacheSolution> _createInitialPopulation(
    List<Groupe> groupes,
    List<Enseignant> enseignants,
    int size,
    Map<String, EnseignantPreferences> preferences,
    double ciMin,
    double ciMax,
  ) {
    final population = <TacheSolution>[];
    final groupeMap = {for (var g in groupes) g.id: g};

    for (int i = 0; i < size; i++) {
      final allocations = <String, List<String>>{
        for (var e in enseignants) e.id: []
      };
      final unallocatedGroupes = List<String>.from(groupes.map((g) => g.id));
      final shuffledEnseignants = List<Enseignant>.from(enseignants)..shuffle(_random);

      final ciCible = (ciMin + ciMax) / 2;

      // Pour chaque prof, allouer les cours préférés
      for (var enseignant in shuffledEnseignants) {
        final enseignantPrefs = preferences[enseignant.id];
        if (enseignantPrefs == null) continue;

        final preferredCours = List<String>.from(enseignantPrefs.coursSouhaites)..shuffle(_random);

        for (var coursCode in preferredCours) {
          final groupesPourCeCours = unallocatedGroupes
              .where((gId) => groupeMap[gId]?.cours == coursCode)
              .toList()..shuffle(_random);

          for (var groupeId in groupesPourCeCours) {
            final groupe = groupeMap[groupeId]!;
            final currentCI = _ciCalculator.calculateCI(
              (allocations[enseignant.id] ?? []).map((gId) => groupeMap[gId]!).toList()
            );
            final groupeCI = _ciCalculator.calculateCI([groupe]);

            if (currentCI + groupeCI <= ciCible) {
              allocations[enseignant.id]!.add(groupeId);
              unallocatedGroupes.remove(groupeId);
            }
          }
        }
      }

      // Allouer les groupes restants aléatoirement
      unallocatedGroupes.shuffle(_random);
      for (var groupeId in unallocatedGroupes) {
        if (enseignants.isNotEmpty) {
          final randomEnseignant = enseignants[_random.nextInt(enseignants.length)];
          allocations[randomEnseignant.id]!.add(groupeId);
        }
      }

      population.add(TacheSolution(
        allocations: allocations,
        groupesNonAlloues: [], // Sera recalculé plus tard
      ));
    }

    return population;
  }

  /// Calcule le score de fitness d'une solution
  double _calculateFitness(
    TacheSolution solution,
    List<Groupe> groupes,
    List<Enseignant> enseignants,
    Map<String, EnseignantPreferences> preferences,
    double ciMin,
    double ciMax,
  ) {
    double score = 0.0;

    final groupeMap = {for (var g in groupes) g.id: g};
    final enseignantsIds = solution.allocations.keys.toSet();

    for (var enseignant in enseignants) {
      final groupeIds = solution.allocations[enseignant.id] ?? [];
      final enseignantGroupes = groupeIds
          .map((id) => groupeMap[id])
          .whereType<Groupe>()
          .toList();

      // 1. Score CI
      final ci = _ciCalculator.calculateCI(enseignantGroupes);
      if (ci >= ciMin && ci <= ciMax) {
        score += weights.wCiBonus;
      } else {
        final distance = ci < ciMin ? (ciMin - ci) : (ci - ciMax);
        score += -weights.wCiPenaltyPerUnit * distance;
      }

      // 2. Nombre de cours distincts à préparer
      final coursDistincts = enseignantGroupes.map((g) => g.cours).toSet();
      final nbCoursDistincts = coursDistincts.length;
      if (nbCoursDistincts == 2) {
        score += weights.wCours2Penalty;
      } else if (nbCoursDistincts == 3) {
        score += weights.wCours3Penalty;
      } else if (nbCoursDistincts >= 4) {
        score += weights.wCours4PlusPenalty;
      }

      // 3. Préférences cours
      final prefs = preferences[enseignant.id];
      if (prefs != null) {
        final coursEnseignant = enseignantGroupes.map((g) => g.cours).toSet();
        final nbCoursSouhaites = coursEnseignant.where((c) => prefs.coursSouhaites.contains(c)).length;
        final nbCoursEvites = coursEnseignant.where((c) => prefs.coursEvites.contains(c)).length;
        if (nbCoursSouhaites > 0 && nbCoursEvites == 0) {
          score += weights.wCoursWishBonus;
        } else if (nbCoursSouhaites == 0 && nbCoursEvites > 0) {
          score += weights.wCoursAvoidPenalty;
        }

        // 4. Préférences collègues
        final collegues = enseignantsIds
            .where((id) => id != enseignant.id)
            .map((id) => enseignants.firstWhere((e) => e.id == id, orElse: () => Enseignant(id: id, email: '')))
            .toList();
        final colleguesEmails = collegues.map((c) => c.email).toSet();
        final nbColleguesSouhaites = colleguesEmails.where((email) => prefs.colleguesSouhaites.contains(email)).length;
        final nbColleguesEvites = colleguesEmails.where((email) => prefs.colleguesEvites.contains(email)).length;
        if (nbColleguesSouhaites > 0 && nbColleguesEvites == 0 && colleguesEmails.isNotEmpty) {
          score += weights.wColWishBonus;
        } else if (nbColleguesEvites > 0 && nbColleguesSouhaites == 0 && colleguesEmails.isNotEmpty) {
          score += weights.wColAvoidPenalty;
        }
      }
    }

    // Pénalité pour les groupes non alloués
    score += weights.wUnallocatedPenalty * solution.groupesNonAlloues.length;

    return score;
  }

  /// Sélection par tournoi
  TacheSolution _tournamentSelection(List<TacheSolution> population, {int tournamentSize = 3}) {
    final tournament = <TacheSolution>[];
    for (int i = 0; i < tournamentSize; i++) {
      tournament.add(population[_random.nextInt(population.length)]);
    }
    tournament.sort((a, b) => (b.fitness ?? 0).compareTo(a.fitness ?? 0));
    return tournament.first;
  }

  /// Version publique du calcul de fitness pour une répartition
  Future<double> calculateFitnessForRepartition(
    Repartition repartition,
    Tache tache,
    List<Groupe> groupes,
    List<dynamic> preferences,
  ) async {
    final solution = TacheSolution(
      allocations: repartition.allocations,
      groupesNonAlloues: repartition.groupesNonAlloues,
    );

    final enseignantIds = repartition.allocations.keys.toList();
    final enseignants = <Enseignant>[];
    
    // Récupérer les enseignants depuis la tâche
    for (int i = 0; i < tache.enseignantIds.length; i++) {
      final id = tache.enseignantIds[i];
      if (enseignantIds.contains(id)) {
        enseignants.add(Enseignant(
          id: id,
          email: i < tache.enseignantEmails.length ? tache.enseignantEmails[i] : id,
        ));
      }
    }

    // Convertir la liste de préférences en Map
    final prefsMap = <String, EnseignantPreferences>{};
    for (var pref in preferences) {
      if (pref is EnseignantPreferences) {
        prefsMap[pref.enseignantId] = pref;
      }
    }

    final ciMin = tache.ciMin;
    final ciMax = tache.ciMax;

    return _calculateFitness(solution, groupes, enseignants, prefsMap, ciMin, ciMax);
  }

  /// Crossover (croisement) entre deux solutions
  TacheSolution _crossover(
    TacheSolution parent1,
    TacheSolution parent2,
    List<Enseignant> enseignants,
  ) {
    final child = parent1.copy();
    
    // Pour chaque enseignant, prendre aléatoirement de parent1 ou parent2
    for (var enseignant in enseignants) {
      if (_random.nextBool()) {
        child.allocations[enseignant.id] = List.from(parent2.allocations[enseignant.id] ?? []);
      }
    }

    // Corriger les duplications et groupes manquants
    _repairSolution(child, parent1);

    return child;
  }

  /// Répare une solution pour éviter les duplications
  void _repairSolution(TacheSolution solution, TacheSolution reference) {
    // Collecter tous les groupes alloués
    final allGroupes = <String>{};
    final duplicates = <String>[];

    for (var groupeIds in solution.allocations.values) {
      for (var groupeId in groupeIds) {
        if (allGroupes.contains(groupeId)) {
          duplicates.add(groupeId);
        } else {
          allGroupes.add(groupeId);
        }
      }
    }

    // Retirer les duplicatas
    for (var groupeId in duplicates) {
      for (var groupeIds in solution.allocations.values) {
        groupeIds.remove(groupeId);
      }
    }

    // Ajouter les groupes manquants depuis la référence
    for (var entry in reference.allocations.entries) {
      for (var groupeId in entry.value) {
        if (!allGroupes.contains(groupeId)) {
          solution.allocations[entry.key]!.add(groupeId);
          allGroupes.add(groupeId);
        }
      }
    }
  }

  /// Mutation d'une solution
  void _mutate(
    TacheSolution solution,
    List<Groupe> groupes,
    List<Enseignant> enseignants,
  ) {
    if (enseignants.length < 2) return;

    final mutationType = _random.nextInt(2);

    if (mutationType == 0) {
      // Mutation 1: Déplacer un groupe d'un enseignant à un autre
      _mutateMove(solution, enseignants);
    } else {
      // Mutation 2: Transposition à trois enseignants
      _mutateTransposition(solution, enseignants);
    }
  }

  /// Mutation: déplacer un groupe d'un enseignant à un autre
  void _mutateMove(TacheSolution solution, List<Enseignant> enseignants) {
    // Trouver un enseignant avec au moins un groupe
    final enseignantsWithGroupes = enseignants
        .where((e) => (solution.allocations[e.id] ?? []).isNotEmpty)
        .toList();

    if (enseignantsWithGroupes.isEmpty) return;

    final fromEnseignant = enseignantsWithGroupes[_random.nextInt(enseignantsWithGroupes.length)];
    final groupes = solution.allocations[fromEnseignant.id]!;
    
    if (groupes.isEmpty) return;

    final groupeToMove = groupes[_random.nextInt(groupes.length)];
    
    // Choisir un autre enseignant
    final toEnseignant = enseignants[_random.nextInt(enseignants.length)];
    
    if (fromEnseignant.id == toEnseignant.id) return;

    // Déplacer le groupe
    solution.allocations[fromEnseignant.id]!.remove(groupeToMove);
    solution.allocations[toEnseignant.id]!.add(groupeToMove);
  }

  /// Mutation: transposition circulaire entre trois enseignants
  void _mutateTransposition(TacheSolution solution, List<Enseignant> enseignants) {
    if (enseignants.length < 3) return;

    // Choisir 3 enseignants différents avec des groupes
    final enseignantsWithGroupes = enseignants
        .where((e) => (solution.allocations[e.id] ?? []).isNotEmpty)
        .toList();

    if (enseignantsWithGroupes.length < 3) return;

    enseignantsWithGroupes.shuffle(_random);
    final e1 = enseignantsWithGroupes[0];
    final e2 = enseignantsWithGroupes[1];
    final e3 = enseignantsWithGroupes[2];

    final g1 = solution.allocations[e1.id]!;
    final g2 = solution.allocations[e2.id]!;
    final g3 = solution.allocations[e3.id]!;

    if (g1.isEmpty || g2.isEmpty || g3.isEmpty) return;

    // Prendre un groupe de chaque enseignant
    final groupe1 = g1[_random.nextInt(g1.length)];
    final groupe2 = g2[_random.nextInt(g2.length)];
    final groupe3 = g3[_random.nextInt(g3.length)];

    // Transposition circulaire: E1 -> E2, E2 -> E3, E3 -> E1
    solution.allocations[e1.id]!.remove(groupe1);
    solution.allocations[e2.id]!.remove(groupe2);
    solution.allocations[e3.id]!.remove(groupe3);

    solution.allocations[e2.id]!.add(groupe1);
    solution.allocations[e3.id]!.add(groupe2);
    solution.allocations[e1.id]!.add(groupe3);
  }
}
