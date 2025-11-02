import 'dart:math';
import '../models/groupe.dart';
import '../models/enseignant.dart';
import '../models/enseignant_preferences.dart';
import '../models/repartition.dart';
import 'ci_calculator_service.dart';
import 'score_repartition_service.dart';

/// Représente une solution d'allocation pour un enseignant
class _AllocationSolution {
  final List<String> groupeIds;
  final double ci;

  _AllocationSolution({
    required this.groupeIds,
    required this.ci,
  });
}

/// Service pour générer des populations initiales de répartitions
class PopulationGeneratorService {
  final CICalculatorService _ciCalculator = CICalculatorService();
  final ScoreRepartitionService _scoreService = ScoreRepartitionService();
  final Random _random = Random();

  /// Génère une population initiale en saturant les préférences des enseignants
  List<Map<String, List<String>>> generatePopulationByPreferences({
    required List<Groupe> groupes,
    required List<Enseignant> enseignants,
    required Map<String, EnseignantPreferences> preferences,
    required double ciMin,
    required double ciMax,
    required int count,
  }) {
    final population = <Map<String, List<String>>>[];
    final groupeMap = {for (var g in groupes) g.id: g};

    // Afficher les informations initiales
    print('\n╔═══════════════════════════════════════════════════════════════╗');
    print('║ GÉNÉRATION DE RÉPARTITIONS PAR PRÉFÉRENCES');
    print('╚═══════════════════════════════════════════════════════════════╝');
    print('\n📋 Liste des enseignants (${enseignants.length}):');
    print('   ${enseignants.map((e) => e.displayName).join(", ")}');
    print('\n📚 Liste des groupes (${groupes.length}):');
    print('   ${groupes.map((g) => '${g.cours}-${g.numeroGroupe}').join(", ")}');
    print('\n🎯 Répartitions à générer: $count');
    print('═══════════════════════════════════════════════════════════════\n');

    for (int i = 0; i < count; i++) {
      print('\n=== Génération de la répartition ${i + 1}/$count ===');

      final allocations = <String, List<String>>{
        for (var e in enseignants) e.id: []
      };
      final unallocatedGroupes = List<String>.from(groupes.map((g) => g.id));

      // 1. Trier les enseignants : ceux avec préférences en premier
      final orderedEnseignants = _sortEnseignantsByPreferences(enseignants, preferences);

      // Allouer les cours pour chaque enseignant
      for (var enseignant in orderedEnseignants) {
        _allocatePreferredCoursesForEnseignant(
          enseignant: enseignant,
          preferences: preferences,
          allocations: allocations,
          unallocatedGroupes: unallocatedGroupes,
          groupeMap: groupeMap,
        );
      }

      // Afficher le résumé
      _printRepartitionSummary(
        repartitionIndex: i + 1,
        enseignants: enseignants,
        allocations: allocations,
        groupeMap: groupeMap,
      );

      population.add(allocations);
    }

    return population;
  }

  /// Trie les enseignants : ceux avec préférences en premier, puis ceux sans
  List<Enseignant> _sortEnseignantsByPreferences(
    List<Enseignant> enseignants,
    Map<String, EnseignantPreferences> preferences,
  ) {
    // Séparer les enseignants avec et sans préférences
    final avecPreferences = <Enseignant>[];
    final sansPreferences = <Enseignant>[];

    for (var enseignant in enseignants) {
      final prefs = preferences[enseignant.id];
      if (prefs != null && (prefs.coursSouhaites.isNotEmpty || prefs.coursEvites.isNotEmpty)) {
        avecPreferences.add(enseignant);
      } else {
        sansPreferences.add(enseignant);
      }
    }

    // Mélanger chaque groupe séparément
    avecPreferences.shuffle(_random);
    sansPreferences.shuffle(_random);

    print('\n📊 Ordre d\'allocation:');
    print('   Avec préférences (${avecPreferences.length}): ${avecPreferences.map((e) => e.displayName).join(", ")}');
    print('   Sans préférences (${sansPreferences.length}): ${sansPreferences.map((e) => e.displayName).join(", ")}');

    // Retourner la liste combinée : avec préférences d'abord
    return [...avecPreferences, ...sansPreferences];
  }

  /// Alloue les cours pour un enseignant avec backtracking
  /// Utilise tous les cours disponibles en privilégiant les cours préférés
  void _allocatePreferredCoursesForEnseignant({
    required Enseignant enseignant,
    required Map<String, EnseignantPreferences> preferences,
    required Map<String, List<String>> allocations,
    required List<String> unallocatedGroupes,
    required Map<String, Groupe> groupeMap,
  }) {
    const ciCible = 40.0;
    const ciMin = 38.0;
    const ciMax = 46.0;

    print('\nDébut de l\'allocation pour prof ${enseignant.displayName}');

    // Récupérer tous les cours disponibles
    final allCoursAvailable = unallocatedGroupes
        .map((gId) => groupeMap[gId]?.cours)
        .whereType<String>()
        .toSet()
        .toList();

    if (allCoursAvailable.isEmpty) {
      print('  Aucun groupe disponible');
      return;
    }

    // Séparer les cours en préférés et autres
    final enseignantPrefs = preferences[enseignant.id];
    final preferredCours = <String>[];
    final otherCours = <String>[];

    for (var cours in allCoursAvailable) {
      if (enseignantPrefs != null && enseignantPrefs.coursSouhaites.contains(cours)) {
        preferredCours.add(cours);
      } else {
        otherCours.add(cours);
      }
    }

    // Mélanger les listes pour avoir de la variation
    preferredCours.shuffle(_random);
    otherCours.shuffle(_random);

    // Combiner : cours préférés en premier, puis les autres
    final allCoursOrdered = [...preferredCours, ...otherCours];

    if (preferredCours.isNotEmpty) {
      print('  Cours préférés disponibles: ${preferredCours.join(", ")}');
    }
    if (otherCours.isNotEmpty) {
      print('  Autres cours disponibles: ${otherCours.take(5).join(", ")}${otherCours.length > 5 ? "..." : ""}');
    }

    // Trouver la meilleure combinaison avec backtracking
    final bestSolution = _findBestAllocationWithBacktracking(
      enseignant: enseignant,
      preferredCours: allCoursOrdered, // Utilise tous les cours
      unallocatedGroupes: unallocatedGroupes,
      groupeMap: groupeMap,
      ciCible: ciCible,
      ciMin: ciMin,
      ciMax: ciMax,
      isPreferredCours: (cours) => preferredCours.contains(cours),
    );

    if (bestSolution != null) {
      // Appliquer la meilleure solution trouvée
      for (var groupeId in bestSolution.groupeIds) {
        allocations[enseignant.id]!.add(groupeId);
        unallocatedGroupes.remove(groupeId);
      }

      final coursDistincts = bestSolution.groupeIds
          .map((gId) => groupeMap[gId]?.cours)
          .whereType<String>()
          .toSet()
          .length;

      print('  ✅ Solution trouvée: ${bestSolution.groupeIds.length} groupe(s), $coursDistincts cours distinct(s), CI: ${bestSolution.ci.toStringAsFixed(1)}');
    } else {
      print('  ⚠️ Aucune solution optimale trouvée pour ${enseignant.displayName}');
    }
  }

  /// Trouve la meilleure allocation avec une approche itérative simple
  _AllocationSolution? _findBestAllocationWithBacktracking({
    required Enseignant enseignant,
    required List<String> preferredCours,
    required List<String> unallocatedGroupes,
    required Map<String, Groupe> groupeMap,
    required double ciCible,
    required double ciMin,
    required double ciMax,
    required bool Function(String cours) isPreferredCours,
  }) {
    _AllocationSolution? bestSolution;
    double bestScore = double.negativeInfinity;

    print('  🔍 Exploration des combinaisons possibles...');

    // Stratégie simple: essayer d'allouer les cours un par un
    // en privilégiant ceux qui complètent des cours déjà commencés
    final currentAllocation = <String>[];
    double currentCI = 0.0;
    final usedCours = <String>{};

    // 1. D'abord, essayer de prendre des cours préférés complets
    for (var coursCode in preferredCours) {
      if (!isPreferredCours(coursCode)) continue; // Sauter les cours non préférés pour l'instant

      final groupesPourCeCours = unallocatedGroupes
          .where((gId) =>
            groupeMap[gId]?.cours == coursCode &&
            !currentAllocation.contains(gId))
          .toList();

      if (groupesPourCeCours.isEmpty) continue;

      print('    ⭐ Évaluation du cours préféré $coursCode (${groupesPourCeCours.length} groupe(s))');

      // Calculer la CI si on prend TOUS les groupes de ce cours
      double ciAvecTousCours = currentCI;
      for (var gId in groupesPourCeCours) {
        ciAvecTousCours += _ciCalculator.calculateCI([groupeMap[gId]!]);
      }

      // Si on peut prendre tous les groupes sans trop dépasser
      if (ciAvecTousCours <= ciMax + 5) {
        // Ajouter tous les groupes de ce cours
        currentAllocation.addAll(groupesPourCeCours);
        currentCI = ciAvecTousCours;
        usedCours.add(coursCode);
        print('      ✓ Tous les groupes de $coursCode ajoutés (CI: ${currentCI.toStringAsFixed(1)})');

        // Si on est dans la plage cible, évaluer cette solution
        if (currentCI >= ciMin && currentCI <= ciMax) {
          final score = _scoreService.evaluateAllocationScore(
            ci: currentCI,
            ciCible: ciCible,
            ciMin: ciMin,
            ciMax: ciMax,
            nbGroupes: currentAllocation.length,
            nbCoursDistincts: usedCours.length,
            nbCoursPreferred: usedCours.where((c) => isPreferredCours(c)).length,
          );

          if (score > bestScore) {
            bestScore = score;
            bestSolution = _AllocationSolution(
              groupeIds: List.from(currentAllocation),
              ci: currentCI,
            );
            print('    💡 Nouvelle meilleure solution: ${currentAllocation.length} groupe(s), ${usedCours.length} cours, CI: ${currentCI.toStringAsFixed(1)}, Score: ${score.toStringAsFixed(2)}');
          }
        }

        // Si on a atteint la cible, on peut s'arrêter
        if (currentCI >= ciMin) {
          break;
        }
      } else {
        // Essayer de prendre seulement une partie des groupes
        double ciPartiel = currentCI;
        final groupesPartiels = <String>[];

        for (var gId in groupesPourCeCours) {
          final ciGroupe = _ciCalculator.calculateCI([groupeMap[gId]!]);
          if (ciPartiel + ciGroupe <= ciMax + 5) {
            groupesPartiels.add(gId);
            ciPartiel += ciGroupe;
          } else {
            break;
          }
        }

        if (groupesPartiels.isNotEmpty) {
          currentAllocation.addAll(groupesPartiels);
          currentCI = ciPartiel;
          usedCours.add(coursCode);
          print('      ✓ ${groupesPartiels.length}/${groupesPourCeCours.length} groupes de $coursCode ajoutés (CI: ${currentCI.toStringAsFixed(1)})');
        }
      }
    }

    // 2. Si on n'a pas atteint ciMin, compléter avec d'autres cours
    if (currentCI < ciMin) {
      print('    🔸 CI insuffisante (${currentCI.toStringAsFixed(1)}), ajout d\'autres cours...');

      for (var coursCode in preferredCours) {
        if (usedCours.contains(coursCode)) continue; // Déjà utilisé

        final groupesPourCeCours = unallocatedGroupes
            .where((gId) =>
              groupeMap[gId]?.cours == coursCode &&
              !currentAllocation.contains(gId))
            .toList();

        if (groupesPourCeCours.isEmpty) continue;

        final isPreferred = isPreferredCours(coursCode);
        final marker = isPreferred ? '⭐' : '  ';
        print('    $marker Évaluation du cours $coursCode (${groupesPourCeCours.length} groupe(s))');

        // Essayer d'ajouter ce cours
        double ciAvecCours = currentCI;
        final groupesACours = <String>[];

        for (var gId in groupesPourCeCours) {
          final ciGroupe = _ciCalculator.calculateCI([groupeMap[gId]!]);
          if (ciAvecCours + ciGroupe <= ciMax + 5) {
            groupesACours.add(gId);
            ciAvecCours += ciGroupe;
          } else {
            break;
          }
        }

        if (groupesACours.isNotEmpty) {
          currentAllocation.addAll(groupesACours);
          currentCI = ciAvecCours;
          usedCours.add(coursCode);
          print('      ✓ ${groupesACours.length} groupe(s) de $coursCode ajoutés (CI: ${currentCI.toStringAsFixed(1)})');

          // Évaluer la solution
          if (currentCI >= ciMin && currentCI <= ciMax) {
            final score = _scoreService.evaluateAllocationScore(
              ci: currentCI,
              ciCible: ciCible,
              ciMin: ciMin,
              ciMax: ciMax,
              nbGroupes: currentAllocation.length,
              nbCoursDistincts: usedCours.length,
              nbCoursPreferred: usedCours.where((c) => isPreferredCours(c)).length,
            );

            if (score > bestScore) {
              bestScore = score;
              bestSolution = _AllocationSolution(
                groupeIds: List.from(currentAllocation),
                ci: currentCI,
              );
              print('    💡 Nouvelle meilleure solution: ${currentAllocation.length} groupe(s), ${usedCours.length} cours, CI: ${currentCI.toStringAsFixed(1)}, Score: ${score.toStringAsFixed(2)}');
            }
          }

          // Si on a atteint la cible, on s'arrête
          if (currentCI >= ciMin) {
            break;
          }
        }
      }
    }

    return bestSolution;
  }


  /// Affiche un résumé de la répartition générée
  void _printRepartitionSummary({
    required int repartitionIndex,
    required List<Enseignant> enseignants,
    required Map<String, List<String>> allocations,
    required Map<String, Groupe> groupeMap,
  }) {
    print('\n--- Résumé de la répartition $repartitionIndex ---');
    for (var enseignant in enseignants) {
      final groupeIds = allocations[enseignant.id] ?? [];
      final ci = _ciCalculator.calculateCI(
        groupeIds.map((gId) => groupeMap[gId]!).toList()
      );
      final coursDistincts = groupeIds
          .map((gId) => groupeMap[gId]?.cours)
          .whereType<String>()
          .toSet()
          .length;
      print('${enseignant.displayName}: ${groupeIds.length} groupe(s), $coursDistincts cours distinct(s), CI: ${ci.toStringAsFixed(1)}');
    }
  }

  /// Génère des répartitions complètes à partir d'allocations
  List<Repartition> generateRepartitions({
    required List<Map<String, List<String>>> allocations,
    required String tacheId,
    String namePrefix = 'Répartition par préférences',
  }) {
    final repartitions = <Repartition>[];

    for (int i = 0; i < allocations.length; i++) {
      final allocation = allocations[i];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final id = 'repartition_${timestamp}_$i';

      repartitions.add(Repartition(
        id: id,
        nom: '$namePrefix ${i + 1}',
        tacheId: tacheId,
        allocations: allocation,
        groupesNonAlloues: [],
        estValide: false,
        dateCreation: DateTime.now(),
        estAutomatique: true,
      ));
    }

    return repartitions;
  }

  /// Génère et crée directement des répartitions par préférences
  List<Repartition> createRepartitionsByPreferences({
    required List<Groupe> groupes,
    required List<Enseignant> enseignants,
    required Map<String, EnseignantPreferences> preferences,
    required String tacheId,
    required double ciMin,
    required double ciMax,
    required int count,
  }) {
    final allocations = generatePopulationByPreferences(
      groupes: groupes,
      enseignants: enseignants,
      preferences: preferences,
      ciMin: ciMin,
      ciMax: ciMax,
      count: count,
    );

    return generateRepartitions(
      allocations: allocations,
      tacheId: tacheId,
    );
  }
}
