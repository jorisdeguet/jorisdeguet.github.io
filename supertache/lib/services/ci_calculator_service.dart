import '../models/groupe.dart';

/// Service de calcul de la Charge Individuelle (CI) selon la formule officielle
class CICalculatorService {
  /// Calcule la CI totale pour une liste de groupes assignés à un enseignant
  /// 
  /// La formule: CIp = (Pond HC) + (Pond HP) + (Pond PES) + (Pond NES)
  double calculateCI(List<Groupe> groupes) {
    if (groupes.isEmpty) return 0.0;

    // 1. Calculer HC (Heures de Cours)
    final double pondHC = _calculatePondHC(groupes);

    // 2. Calculer HP (Heures de Préparation)
    final double pondHP = _calculatePondHP(groupes);

    // 3. Calculer PES (Période-Étudiant par Semaine)
    final double pondPES = _calculatePondPES(groupes);

    // 4. Calculer NES (Nombre d'Étudiants - facteur de correction)
    final double pondNES = _calculatePondNES(groupes);

    return pondHC + pondHP + pondPES + pondNES;
  }

  /// Calcule la pondération des Heures de Cours (HC)
  /// Formule: HC × 1.2
  double _calculatePondHC(List<Groupe> groupes) {
    double totalHC = 0.0;
    
    for (var groupe in groupes) {
      // HC = heures de théorie + heures de pratique par semaine
      final double hcGroupe = groupe.heuresTheorie + groupe.heuresPratique;
      totalHC += hcGroupe * 1.2;
    }
    
    return totalHC;
  }

  /// Calcule la pondération des Heures de Préparation (HP)
  /// Le multiplicateur varie selon le nombre de préparations différentes
  double _calculatePondHP(List<Groupe> groupes) {
    // Compter le nombre de cours différents (préparations différentes)
    final Set<String> coursUniques = groupes.map((g) => g.cours).toSet();
    final int nbPreparations = coursUniques.length;

    // Calculer le total d'heures pour les préparations
    double totalHP = 0.0;
    for (var coursCode in coursUniques) {
      // Prendre les heures du premier groupe de ce cours
      final groupe = groupes.firstWhere((g) => g.cours == coursCode);
      totalHP += groupe.heuresTheorie + groupe.heuresPratique;
    }

    // Appliquer le coefficient selon le nombre de préparations
    double coefficient;
    if (nbPreparations <= 2) {
      coefficient = 0.9;
    } else if (nbPreparations == 3) {
      coefficient = 1.1;
    } else {
      coefficient = 1.3;
    }

    return totalHP * coefficient;
  }

  /// Calcule la pondération PES (Période-Étudiant par Semaine)
  /// PES = somme de (nb étudiants × heures-cours) pour chaque groupe
  /// Pondération par paliers: 0-415: ×0.04, >415: ×0.07
  double _calculatePondPES(List<Groupe> groupes) {
    // Calculer le PES total
    double totalPES = 0.0;
    for (var groupe in groupes) {
      final double heuresCours = groupe.heuresTheorie + groupe.heuresPratique;
      totalPES += groupe.nombreEtudiants * heuresCours;
    }

    // Appliquer la pondération par paliers
    double ponderation = 0.0;
    
    if (totalPES <= 415) {
      ponderation = totalPES * 0.04;
    } else {
      // Premiers 415 PES
      ponderation = 415 * 0.04;
      // PES au-delà de 415
      ponderation += (totalPES - 415) * 0.07;
    }

    return ponderation;
  }

  /// Calcule la pondération NES (Nombre d'Étudiants - correction)
  /// Si NES >= 75 et heures > 2h/sem: NES × 0.01
  double _calculatePondNES(List<Groupe> groupes) {
    // Calculer le nombre total d'étudiants
    final int totalEtudiants = groupes.fold(0, (sum, g) => sum + g.nombreEtudiants);
    
    // Calculer les heures totales par semaine
    final double totalHeures = groupes.fold(
      0.0, 
      (sum, g) => sum + g.heuresTheorie + g.heuresPratique
    );

    // Appliquer la correction si applicable
    if (totalEtudiants >= 75 && totalHeures > 2) {
      return totalEtudiants * 0.01;
    }

    return 0.0;
  }

  /// Retourne des détails sur le calcul pour débogage
  Map<String, dynamic> getCalculationDetails(List<Groupe> groupes) {
    if (groupes.isEmpty) {
      return {
        'ci': 0.0,
        'pondHC': 0.0,
        'pondHP': 0.0,
        'pondPES': 0.0,
        'pondNES': 0.0,
        'nbPreparations': 0,
        'totalEtudiants': 0,
        'totalHeures': 0.0,
      };
    }

    final coursUniques = groupes.map((g) => g.cours).toSet();
    final totalEtudiants = groupes.fold(0, (sum, g) => sum + g.nombreEtudiants);
    final totalHeures = groupes.fold(
      0.0, 
      (sum, g) => sum + g.heuresTheorie + g.heuresPratique
    );

    final pondHC = _calculatePondHC(groupes);
    final pondHP = _calculatePondHP(groupes);
    final pondPES = _calculatePondPES(groupes);
    final pondNES = _calculatePondNES(groupes);

    return {
      'ci': pondHC + pondHP + pondPES + pondNES,
      'pondHC': pondHC,
      'pondHP': pondHP,
      'pondPES': pondPES,
      'pondNES': pondNES,
      'nbPreparations': coursUniques.length,
      'totalEtudiants': totalEtudiants,
      'totalHeures': totalHeures,
    };
  }
}
