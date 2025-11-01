import 'dart:math';
import '../models/groupe.dart';
import '../models/enseignant.dart';
import '../models/repartition.dart';
import 'ci_calculator_service.dart';

class GeneticAlgorithmService {
  final double ciMin;
  final double ciMax;
  final int populationSize;
  final int maxGenerations;
  final double mutationRate;
  final double crossoverRate;
  final CICalculatorService _ciCalculator = CICalculatorService();

  GeneticAlgorithmService({
    this.ciMin = 35.0,
    this.ciMax = 47.0,
    this.populationSize = 100,
    this.maxGenerations = 500,
    this.mutationRate = 0.1,
    this.crossoverRate = 0.8,
  });

  // Générer une répartition automatique
  Future<Repartition> generateRepartition({
    required String tacheId,
    required List<Groupe> groupes,
    required List<Enseignant> enseignants,
    void Function(int generation, double fitness)? onProgress,
  }) async {
    // Initialiser la population
    List<_Chromosome> population = _initializePopulation(groupes, enseignants);

    _Chromosome? bestChromosome;
    double bestFitness = double.negativeInfinity;
    int lastGeneration = 0;

    // Évolution génétique
    for (int generation = 0; generation < maxGenerations; generation++) {
      lastGeneration = generation;
      
      // Évaluation
      for (var chromosome in population) {
        chromosome.fitness = _evaluateFitness(chromosome, groupes, enseignants);
      }

      // Tri par fitness
      population.sort((a, b) => b.fitness.compareTo(a.fitness));

      // Garder le meilleur
      if (population.first.fitness > bestFitness) {
        bestFitness = population.first.fitness;
        bestChromosome = population.first;
      }

      // Rapporter le progrès
      if (onProgress != null && generation % 10 == 0) {
        onProgress(generation, bestFitness);
      }

      // Condition d'arrêt si solution optimale trouvée
      if (bestFitness >= 1000) break;

      // Sélection et reproduction
      List<_Chromosome> newPopulation = [];
      
      // Élitisme : garder les meilleurs
      int eliteCount = (populationSize * 0.1).round();
      newPopulation.addAll(population.take(eliteCount));

      // Génération de nouveaux individus
      while (newPopulation.length < populationSize) {
        var parent1 = _tournamentSelection(population);
        var parent2 = _tournamentSelection(population);

        if (Random().nextDouble() < crossoverRate) {
          var children = _crossover(parent1, parent2);
          newPopulation.addAll(children);
        } else {
          newPopulation.add(parent1);
        }
      }

      // Mutation
      for (var chromosome in newPopulation.skip(eliteCount)) {
        if (Random().nextDouble() < mutationRate) {
          _mutate(chromosome, enseignants.length);
        }
      }

      population = newPopulation.take(populationSize).toList();
    }

    // Rapporter le progrès final
    if (onProgress != null) {
      onProgress(lastGeneration, bestFitness);
    }

    // Convertir le meilleur chromosome en répartition
    return _chromosomeToRepartition(
      bestChromosome ?? population.first,
      tacheId,
      groupes,
      enseignants,
    );
  }

  List<_Chromosome> _initializePopulation(List<Groupe> groupes, List<Enseignant> enseignants) {
    List<_Chromosome> population = [];
    final random = Random();

    for (int i = 0; i < populationSize; i++) {
      List<int> genes = List.generate(
        groupes.length,
        (_) => random.nextInt(enseignants.length + 1), // +1 pour non alloué
      );
      population.add(_Chromosome(genes));
    }

    return population;
  }

  double _evaluateFitness(_Chromosome chromosome, List<Groupe> groupes, List<Enseignant> enseignants) {
    double fitness = 0;

    // Calculer la CI de chaque enseignant en utilisant le nouveau calculateur
    Map<int, List<Groupe>> enseignantGroupes = {};
    for (int i = 0; i < chromosome.genes.length; i++) {
      int enseignantIndex = chromosome.genes[i];
      if (enseignantIndex < enseignants.length) {
        if (!enseignantGroupes.containsKey(enseignantIndex)) {
          enseignantGroupes[enseignantIndex] = [];
        }
        enseignantGroupes[enseignantIndex]!.add(groupes[i]);
      }
    }

    Map<int, double> enseignantCIs = {};
    for (var entry in enseignantGroupes.entries) {
      enseignantCIs[entry.key] = _ciCalculator.calculateCI(entry.value);
    }

    // Pénalité pour CI hors limites
    int enseignantsInRange = 0;
    double totalDeviation = 0;

    for (var ci in enseignantCIs.values) {
      if (ci >= ciMin && ci <= ciMax) {
        enseignantsInRange++;
        fitness += 100; // Bonus pour être dans la plage
      } else {
        // Pénalité proportionnelle à la distance de la plage
        if (ci < ciMin) {
          totalDeviation += (ciMin - ci);
        } else {
          totalDeviation += (ci - ciMax);
        }
      }
    }

    // Bonus pour avoir tous les enseignants utilisés
    if (enseignantCIs.length == enseignants.length) {
      fitness += 200;
    }

    // Pénalité pour les déviations
    fitness -= totalDeviation * 10;

    // Bonus pour minimiser les groupes non alloués
    int unallocatedCount = chromosome.genes.where((g) => g >= enseignants.length).length;
    fitness -= unallocatedCount * 50;

    // Bonus pour l'équilibre des charges
    if (enseignantCIs.isNotEmpty) {
      var values = enseignantCIs.values.toList();
      double mean = values.reduce((a, b) => a + b) / values.length;
      double variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
      fitness -= variance; // Moins de variance = meilleur
    }

    return fitness;
  }

  _Chromosome _tournamentSelection(List<_Chromosome> population) {
    final random = Random();
    int tournamentSize = 5;
    _Chromosome best = population[random.nextInt(population.length)];

    for (int i = 1; i < tournamentSize; i++) {
      _Chromosome competitor = population[random.nextInt(population.length)];
      if (competitor.fitness > best.fitness) {
        best = competitor;
      }
    }

    return _Chromosome(List.from(best.genes));
  }

  List<_Chromosome> _crossover(_Chromosome parent1, _Chromosome parent2) {
    final random = Random();
    int crossoverPoint = random.nextInt(parent1.genes.length);

    List<int> child1Genes = [
      ...parent1.genes.take(crossoverPoint),
      ...parent2.genes.skip(crossoverPoint),
    ];

    List<int> child2Genes = [
      ...parent2.genes.take(crossoverPoint),
      ...parent1.genes.skip(crossoverPoint),
    ];

    return [_Chromosome(child1Genes), _Chromosome(child2Genes)];
  }

  void _mutate(_Chromosome chromosome, int enseignantCount) {
    final random = Random();
    int geneIndex = random.nextInt(chromosome.genes.length);
    chromosome.genes[geneIndex] = random.nextInt(enseignantCount + 1);
  }

  Repartition _chromosomeToRepartition(
    _Chromosome chromosome,
    String tacheId,
    List<Groupe> groupes,
    List<Enseignant> enseignants,
  ) {
    Map<String, List<String>> allocations = {};
    List<String> groupesNonAlloues = [];

    // Initialiser les allocations pour chaque enseignant
    for (var enseignant in enseignants) {
      allocations[enseignant.id] = [];
    }

    // Construire les allocations et les listes de groupes
    Map<String, List<Groupe>> enseignantGroupes = {};
    for (var enseignant in enseignants) {
      enseignantGroupes[enseignant.id] = [];
    }

    for (int i = 0; i < chromosome.genes.length; i++) {
      int enseignantIndex = chromosome.genes[i];
      if (enseignantIndex < enseignants.length) {
        String enseignantId = enseignants[enseignantIndex].id;
        allocations[enseignantId]!.add(groupes[i].id);
        enseignantGroupes[enseignantId]!.add(groupes[i]);
      } else {
        groupesNonAlloues.add(groupes[i].id);
      }
    }

    // Vérifier si la répartition est valide
    bool estValide = true;
    for (var enseignant in enseignants) {
      double ci = _ciCalculator.calculateCI(enseignantGroupes[enseignant.id]!);
      if (ci < ciMin || ci > ciMax) {
        estValide = false;
        break;
      }
    }

    return Repartition(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tacheId: tacheId,
      nom: 'Répartition génétique ${DateTime.now().toString().substring(0, 16)}',
      dateCreation: DateTime.now(),
      allocations: allocations,
      groupesNonAlloues: groupesNonAlloues,
      estValide: estValide,
      methode: 'genetique',
    );
  }
}

class _Chromosome {
  List<int> genes; // Index de l'enseignant pour chaque groupe
  double fitness = 0;

  _Chromosome(this.genes);
}
