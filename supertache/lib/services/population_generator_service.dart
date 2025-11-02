import 'dart:math';
import '../models/groupe.dart';
import '../models/enseignant.dart';
import '../models/enseignant_preferences.dart';
import '../models/repartition.dart';
import 'ci_calculator_service.dart';

/// Service pour générer des populations initiales de répartitions
class PopulationGeneratorService {
  final CICalculatorService _ciCalculator = CICalculatorService();
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
      final shuffledEnseignants = List<Enseignant>.from(enseignants)..shuffle(_random);

      // Allouer les cours préférés pour chaque enseignant
      for (var enseignant in shuffledEnseignants) {
        _allocatePreferredCoursesForEnseignant(
          enseignant: enseignant,
          preferences: preferences,
          allocations: allocations,
          unallocatedGroupes: unallocatedGroupes,
          groupeMap: groupeMap,
        );
      }

      // Allouer les groupes restants
      _allocateRemainingGroupes(
        enseignants: enseignants,
        allocations: allocations,
        unallocatedGroupes: unallocatedGroupes,
        groupeMap: groupeMap,
      );

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

  /// Alloue les cours préférés pour un enseignant
  void _allocatePreferredCoursesForEnseignant({
    required Enseignant enseignant,
    required Map<String, EnseignantPreferences> preferences,
    required Map<String, List<String>> allocations,
    required List<String> unallocatedGroupes,
    required Map<String, Groupe> groupeMap,
  }) {
    const ciCible = 40.0;
    print('\nDébut de l\'allocation pour prof ${enseignant.displayName}');

    final enseignantPrefs = preferences[enseignant.id];
    if (enseignantPrefs == null || enseignantPrefs.coursSouhaites.isEmpty) {
      print('  Aucune préférence définie pour ce prof');
      return;
    }

    final preferredCours = List<String>.from(enseignantPrefs.coursSouhaites)..shuffle(_random);
    print('  Cours préférés: ${preferredCours.join(", ")}');

    double currentCI = 0.0;
    int nbGroupesAlloues = 0;

    // Essayer d'allouer les cours préférés jusqu'à atteindre la CI cible
    for (var coursCode in preferredCours) {
      if (currentCI >= ciCible) {
        print('  CI cible atteinte (${currentCI.toStringAsFixed(1)}), passage au prof suivant');
        break;
      }

      final result = _allocateCoursGroupes(
        enseignant: enseignant,
        coursCode: coursCode,
        currentCI: currentCI,
        ciCible: ciCible,
        allocations: allocations,
        unallocatedGroupes: unallocatedGroupes,
        groupeMap: groupeMap,
      );

      currentCI = result.newCI;
      nbGroupesAlloues += result.nbGroupesAdded;
    }

    print('  Résumé pour ${enseignant.displayName}: $nbGroupesAlloues groupe(s), CI totale: ${currentCI.toStringAsFixed(1)}');
  }

  /// Résultat de l'allocation d'un cours
  ({double newCI, int nbGroupesAdded}) _allocateCoursGroupes({
    required Enseignant enseignant,
    required String coursCode,
    required double currentCI,
    required double ciCible,
    required Map<String, List<String>> allocations,
    required List<String> unallocatedGroupes,
    required Map<String, Groupe> groupeMap,
  }) {
    // Chercher les groupes de ce cours qui ne sont pas encore alloués
    final groupesPourCeCours = unallocatedGroupes
        .where((gId) => groupeMap[gId]?.cours == coursCode)
        .toList()..shuffle(_random);

    if (groupesPourCeCours.isEmpty) {
      print('  Aucun groupe disponible pour le cours $coursCode');
      return (newCI: currentCI, nbGroupesAdded: 0);
    }

    print('  Cours préféré: $coursCode (${groupesPourCeCours.length} groupe(s) disponible(s))');

    double updatedCI = currentCI;
    int nbAdded = 0;

    // Allouer TOUS les groupes de ce cours préféré (pour minimiser le nombre de cours à préparer)
    for (var groupeId in groupesPourCeCours) {
      final groupe = groupeMap[groupeId]!;
      final groupeCI = _ciCalculator.calculateCI([groupe]);

      // Vérifier si on peut encore ajouter sans trop dépasser la cible
      // On accepte de dépasser un peu pour finir un cours commencé
      if (updatedCI + groupeCI <= ciCible + 10.0) {
        allocations[enseignant.id]!.add(groupeId);
        unallocatedGroupes.remove(groupeId);
        updatedCI += groupeCI;
        nbAdded++;
        print('    ✓ Ajout du groupe ${groupe.cours}-${groupe.numeroGroupe} (CI: ${groupeCI.toStringAsFixed(1)}, Total: ${updatedCI.toStringAsFixed(1)})');
      } else {
        print('    ✗ Groupe ${groupe.cours}-${groupe.numeroGroupe} ignoré (dépasserait la CI cible)');
      }
    }

    return (newCI: updatedCI, nbGroupesAdded: nbAdded);
  }

  /// Alloue les groupes restants aux enseignants avec le moins de CI
  void _allocateRemainingGroupes({
    required List<Enseignant> enseignants,
    required Map<String, List<String>> allocations,
    required List<String> unallocatedGroupes,
    required Map<String, Groupe> groupeMap,
  }) {
    if (unallocatedGroupes.isEmpty) return;

    print('\n--- Allocation des ${unallocatedGroupes.length} groupe(s) restant(s) ---');
    unallocatedGroupes.shuffle(_random);

    for (var groupeId in unallocatedGroupes) {
      if (enseignants.isEmpty) continue;

      // Trouver le prof avec le moins de CI pour équilibrer
      var bestEnseignant = enseignants.first;
      var minCI = _ciCalculator.calculateCI(
        (allocations[bestEnseignant.id] ?? []).map((gId) => groupeMap[gId]!).toList()
      );

      for (var enseignant in enseignants.skip(1)) {
        final ci = _ciCalculator.calculateCI(
          (allocations[enseignant.id] ?? []).map((gId) => groupeMap[gId]!).toList()
        );
        if (ci < minCI) {
          minCI = ci;
          bestEnseignant = enseignant;
        }
      }

      allocations[bestEnseignant.id]!.add(groupeId);
      final groupe = groupeMap[groupeId]!;
      print('  Groupe ${groupe.cours}-${groupe.numeroGroupe} alloué à ${bestEnseignant.displayName}');
    }
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

