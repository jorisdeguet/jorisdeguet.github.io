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

    // Fallback si on ne trouve pas de solution dans la plage CI mais avec >= 3 groupes
    _AllocationSolution? fallbackSolution;
    double fallbackScore = double.negativeInfinity;

    print('  🔍 Exploration des combinaisons possibles...');

    // Construire une map cours -> groupes disponibles
    final Map<String, List<String>> courseToGroups = {};
    for (var gId in unallocatedGroupes) {
      final g = groupeMap[gId];
      if (g == null) continue;
      courseToGroups.putIfAbsent(g.cours, () => []).add(gId);
    }

    if (courseToGroups.isEmpty) return null;

    // Séparer les cours préférés et neutres et les classifier par taille (heures)
    final preferredHeavy = <String>[]; // >= 5h
    final preferredMedium = <String>[]; // 4h
    final preferredSmall = <String>[]; // 3h

    final otherHeavy = <String>[];
    final otherMedium = <String>[];
    final otherSmall = <String>[];

    for (var cours in courseToGroups.keys) {
      final firstGroupId = courseToGroups[cours]!.first;
      final grp = groupeMap[firstGroupId]!;
      final double heures = grp.heuresTheorie + grp.heuresPratique;

      final bool pref = isPreferredCours(cours);
      if (heures >= 5.0) {
        if (pref) preferredHeavy.add(cours); else otherHeavy.add(cours);
      } else if (heures >= 4.0) {
        if (pref) preferredMedium.add(cours); else otherMedium.add(cours);
      } else {
        if (pref) preferredSmall.add(cours); else otherSmall.add(cours);
      }
    }

    // Ordre de priorité: préférés lourds -> préférés 4h -> préférés 3h -> neutres lourds -> neutres 4h -> neutres 3h
    final orderedCourses = [
      ...preferredHeavy,
      ...preferredMedium,
      ...preferredSmall,
      ...otherHeavy,
      ...otherMedium,
      ...otherSmall,
    ];

    // Limiter la recherche: nombre max de groupes à tester par prof
    const int maxTotalGroups = 6;

    final currentAllocation = <String>[];
    double currentCI = 0.0;
    final usedCours = <String>{};

    double computeCIForAdded(List<String> addedGroupIds) {
      double sum = 0.0;
      for (var id in addedGroupIds) {
        final g = groupeMap[id];
        if (g != null) sum += _ciCalculator.calculateCI([g]);
      }
      return sum;
    }

    void evaluateCurrent(bool preferInRange) {
      final nbGroupes = currentAllocation.length;
      final nbCoursDistincts = usedCours.length;
      final nbCoursPreferred = usedCours.where((c) => isPreferredCours(c)).length;

      final score = _scoreService.evaluateAllocationScore(
        ci: currentCI,
        ciCible: ciCible,
        ciMin: ciMin,
        ciMax: ciMax,
        nbGroupes: nbGroupes,
        nbCoursDistincts: nbCoursDistincts,
        nbCoursPreferred: nbCoursPreferred,
      );

      if (currentCI >= ciMin && currentCI <= ciMax && nbGroupes >= 3) {
        if (score > bestScore) {
          bestScore = score;
          bestSolution = _AllocationSolution(groupeIds: List.from(currentAllocation), ci: currentCI);
          print('    💡 Nouvelle meilleure solution (dans plage CI): ${currentAllocation.length} groupe(s), ${usedCours.length} cours, CI: ${currentCI.toStringAsFixed(1)}, Score: ${score.toStringAsFixed(2)}');
        }
      } else if (nbGroupes >= 3) {
        // Garder un fallback si on n'a rien de valide
        if (score > fallbackScore) {
          fallbackScore = score;
          fallbackSolution = _AllocationSolution(groupeIds: List.from(currentAllocation), ci: currentCI);
          print('    ⚠️ Nouvelle solution de repli (>=3 groupes, hors CI): ${currentAllocation.length} groupe(s), ${usedCours.length} cours, CI: ${currentCI.toStringAsFixed(1)}, Score: ${score.toStringAsFixed(2)}');
        }
      }
    }

    // Recherche DFS limitée
    void dfs(int startIndex) {
      // Évaluer la solution courante
      evaluateCurrent(true);

      if (currentAllocation.length >= maxTotalGroups) return;

      for (int i = startIndex; i < orderedCourses.length; i++) {
        final coursCode = orderedCourses[i];
        final groupesDisponibles = courseToGroups[coursCode]!
            .where((gId) => !currentAllocation.contains(gId))
            .toList();

        if (groupesDisponibles.isEmpty) continue;

        // Autoriser jusqu'à 3 groupes par cours (ou le nombre disponible)
        final maxTake = min(3, groupesDisponibles.length);

        for (int take = 1; take <= maxTake; take++) {
          final toAdd = groupesDisponibles.take(take).toList();
          final addedCI = computeCIForAdded(toAdd);

          // Si l'ajout dépasse trop la limite, sauter
          if (currentCI + addedCI > ciMax + 5) {
            // tenter une quantité moindre
            continue;
          }

          // Appliquer l'ajout
          currentAllocation.addAll(toAdd);
          currentCI += addedCI;
          usedCours.add(coursCode);

          // Évaluer
          evaluateCurrent(true);

          // Si on est déjà dans la plage CI et au moins 3 groupes, on peut tenter d'enregistrer et ne pas explorer plus profond
          if (currentCI >= ciMin && currentCI <= ciMax && currentAllocation.length >= 3) {
            // On continue quand même pour trouver éventuellement une meilleure solution
            dfs(i + 1);
          } else {
            // Continuer la recherche en ajoutant d'autres cours
            if (currentAllocation.length < maxTotalGroups) {
              dfs(i + 1);
            }
          }

          // Annuler l'ajout
          for (var id in toAdd) {
            currentAllocation.remove(id);
          }
          currentCI -= addedCI;
          // retirer le cours des utilisés si plus aucun groupe de ce cours n'est présent
          if (!currentAllocation.any((gId) => groupeMap[gId]?.cours == coursCode)) {
            usedCours.remove(coursCode);
          }
        }
      }
    }

    dfs(0);

    if (bestSolution != null) return bestSolution;
    return fallbackSolution;
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
