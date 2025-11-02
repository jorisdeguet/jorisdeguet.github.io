import '../models/groupe.dart';
import '../models/enseignant.dart';
import '../models/enseignant_preferences.dart';
import '../models/repartition.dart';
import '../models/tache.dart';
import 'ci_calculator_service.dart';

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

/// Service pour calculer le score (fitness) d'une répartition
class ScoreRepartitionService {
  final CICalculatorService _ciCalculator = CICalculatorService();

  /// Calcule le score de fitness d'une répartition
  double calculateScore({
    required Map<String, List<String>> allocations,
    required List<String> groupesNonAlloues,
    required List<Groupe> groupes,
    required List<Enseignant> enseignants,
    required Map<String, EnseignantPreferences> preferences,
    required double ciMin,
    required double ciMax,
    FitnessWeights weights = const FitnessWeights(),
  }) {
    double score = 0.0;

    final groupeMap = {for (var g in groupes) g.id: g};
    final enseignantsIds = allocations.keys.toSet();

    for (var enseignant in enseignants) {
      final groupeIds = allocations[enseignant.id] ?? [];
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
    score += weights.wUnallocatedPenalty * groupesNonAlloues.length;

    return score;
  }

  /// Calcule le score pour une répartition existante
  Future<double> calculateScoreForRepartition(
    Repartition repartition,
    Tache tache,
    List<Groupe> groupes,
    List<dynamic> preferences,
  ) async {
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

    return calculateScore(
      allocations: repartition.allocations,
      groupesNonAlloues: repartition.groupesNonAlloues,
      groupes: groupes,
      enseignants: enseignants,
      preferences: prefsMap,
      ciMin: ciMin,
      ciMax: ciMax,
    );
  }
}

