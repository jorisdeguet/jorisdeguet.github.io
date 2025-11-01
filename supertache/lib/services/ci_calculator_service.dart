import '../models/groupe.dart';

/// Service de calcul de la Charge Individuelle (CI) selon la formule officielle
class CICalculatorService {
  /// Calcule la CI totale pour une liste de groupes assignés à un enseignant
  /// 
  /// La formule: CIp = (Pond HC) + (Pond HP) + (Pond PES) + (Pond NES)
  double calculateCI(List<Groupe> groupes) {
    if (groupes.isEmpty) return 0.0;

    // 1. Calculer HC (Heures de Cours)
    final double pondHC = calculatePondHC(groupes);

    // 2. Calculer HP (Heures de Préparation)
    final double pondHP = calculatePondHP(groupes);

    // 3. Calculer PES (Période-Étudiant par Semaine)
    final double pondPES = calculatePondPES(groupes);

    // 4. Calculer NES (Nombre d'Étudiants - facteur de correction)
    final double pondNES = calculatePondNES(groupes);

    return pondHC + pondHP + pondPES + pondNES;
  }

  /// Calcule la pondération des Heures de Cours (HC)
  /// Formule: HC × 1.2
  double calculatePondHC(List<Groupe> groupes) {
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
  double calculatePondHP(List<Groupe> groupes) {
    // Compter le nombre de cours différents (préparations différentes)
    final Set<String> coursUniques = groupes.map((g) => g.cours).toSet();
    final int nbPreparations = coursUniques.length;

    // Calculer HP = somme des heures de chaque cours DIFFÉRENT (pas par groupe)
    // Pour chaque cours unique, on prend sa pondération (théorie + pratique)
    double totalHP = 0.0;
    for (var coursCode in coursUniques) {
      // Prendre les heures du premier groupe de ce cours (tous les groupes du même cours ont les mêmes heures)
      final groupe = groupes.firstWhere((g) => g.cours == coursCode);
      totalHP += groupe.heuresTheorie + groupe.heuresPratique;
    }

    // Appliquer le coefficient selon le nombre de préparations
    final coefficient = getHPCoefficient(nbPreparations);

    return totalHP * coefficient;
  }

  /// Retourne le coefficient HP selon le nombre de préparations différentes
  double getHPCoefficient(int nbPreparations) {
    if (nbPreparations <= 2) {
      return 0.9;
    } else if (nbPreparations == 3) {
      return 1.1;
    } else {
      return 1.75;
    }
  }

  /// Calcule le nombre d'heures de préparation (HP brut, avant coefficient)
  double calculateHP(List<Groupe> groupes) {
    final Set<String> coursUniques = groupes.map((g) => g.cours).toSet();
    double totalHP = 0.0;
    for (var coursCode in coursUniques) {
      final groupe = groupes.firstWhere((g) => g.cours == coursCode);
      totalHP += groupe.heuresTheorie + groupe.heuresPratique;
    }
    return totalHP;
  }

  /// Calcule le nombre d'heures de cours (HC brut, avant coefficient)
  double calculateHC(List<Groupe> groupes) {
    return groupes.fold(0.0, (sum, g) => sum + g.heuresTheorie + g.heuresPratique);
  }

  /// Calcule le nombre de cours différents
  int calculateNbCoursDifferents(List<Groupe> groupes) {
    return groupes.map((g) => g.cours).toSet().length;
  }

  /// Calcule la pondération PES (Période-Étudiant par Semaine)
  /// PES = somme de (nb étudiants × heures-cours) pour chaque groupe
  /// Pondération par paliers: 0-415: ×0.04, >415: ×0.07
  double calculatePondPES(List<Groupe> groupes) {
    // Calculer le PES total
    final totalPES = calculatePES(groupes);

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

  /// Calcule le PES total (Période-Étudiant par Semaine)
  double calculatePES(List<Groupe> groupes) {
    double totalPES = 0.0;
    for (var groupe in groupes) {
      final double heuresCours = groupe.heuresTheorie + groupe.heuresPratique;
      totalPES += groupe.nombreEtudiants * heuresCours;
    }
    return totalPES;
  }

  /// Calcule la pondération NES (Nombre d'Étudiants - correction)
  /// Si NES >= 75 et heures > 2h/sem: NES × 0.01
  double calculatePondNES(List<Groupe> groupes) {
    final nes = calculateNES(groupes);
    final totalHeures = calculateHC(groupes);

    double result = 0.0;
    
    if (nes >= 75) {
      result += nes * 0.01;
    }
    
    if (nes > 160) {
      result += ((nes - 160) * (nes - 160)) * 0.1;
    }

    return result;
  }

  /// Calcule le NES (Nombre d'Étudiants Simplifiés)
  /// NES = NES1 + (0.8 × NES2)
  double calculateNES(List<Groupe> groupes) {
    final nes1 = calculateNES1(groupes);
    final nes2 = calculateNES2(groupes);
    return nes1 + (0.8 * nes2);
  }

  /// Calcule NES1 (étudiants des cours avec pondération >= 3)
  double calculateNES1(List<Groupe> groupes) {
    final Set<String> etudiantsUniques = {};
    
    for (var groupe in groupes) {
      final ponderation = groupe.heuresTheorie + groupe.heuresPratique;
      if (ponderation >= 3) {
        for (int i = 0; i < groupe.nombreEtudiants; i++) {
          etudiantsUniques.add('${groupe.id}_etudiant_$i');
        }
      }
    }
    
    return etudiantsUniques.length.toDouble();
  }

  /// Calcule NES2 (étudiants des cours avec 2 <= pondération < 3)
  double calculateNES2(List<Groupe> groupes) {
    final Set<String> etudiantsUniques = {};
    
    for (var groupe in groupes) {
      final ponderation = groupe.heuresTheorie + groupe.heuresPratique;
      if (ponderation >= 2 && ponderation < 3) {
        for (int i = 0; i < groupe.nombreEtudiants; i++) {
          etudiantsUniques.add('${groupe.id}_etudiant_$i');
        }
      }
    }
    
    return etudiantsUniques.length.toDouble();
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
    final totalHeures = calculateHC(groupes);

    final pondHC = calculatePondHC(groupes);
    final pondHP = calculatePondHP(groupes);
    final pondPES = calculatePondPES(groupes);
    final pondNES = calculatePondNES(groupes);

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
