import 'groupe.dart';
import 'bloc_ci_fixe.dart';
import '../services/ci_calculator_service.dart';

class Tache {
  final String id;
  final String nom; // Nom de la tâche (ex: "Automne 2024")
  final DateTime dateCreation;
  final SessionType type; // Automne ou Hiver
  final int year;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> enseignantEmails; // Emails des enseignants inclus
  final List<String> enseignantIds; // IDs des enseignants (rempli après résolution)
  final List<String> groupeIds; // IDs des groupes

  // Blocs de CI fixes (PVRTT, coordination, etc.)
  final List<BlocCIFixe> blocsCIFixes;

  // Paramètres pour l'algorithme génétique
  final double ciMin; // CI minimale acceptée (par défaut 38.0)
  final double ciMax; // CI maximale acceptée (par défaut 46.0)

  Tache({
    required this.id,
    required this.nom,
    required this.dateCreation,
    required this.type,
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.enseignantEmails,
    this.enseignantIds = const [],
    this.groupeIds = const [],
    this.blocsCIFixes = const [],
    this.ciMin = 38.0,
    this.ciMax = 46.0,
  });

  double calculateCITotale(List<Groupe> groupes) {
    final ciCalculator = CICalculatorService();
    return ciCalculator.calculateCI(groupes);
  }

  /// Calcule la CI fixe totale pour un enseignant donné
  double getCIFixeForEnseignant(String enseignantEmail) {
    return blocsCIFixes
        .where((bloc) => bloc.enseignantEmail.toLowerCase() == enseignantEmail.toLowerCase())
        .fold(0.0, (sum, bloc) => sum + bloc.ci);
  }

  /// Retourne tous les blocs de CI fixes pour un enseignant donné
  List<BlocCIFixe> getBlocsCIFixesForEnseignant(String enseignantEmail) {
    return blocsCIFixes
        .where((bloc) => bloc.enseignantEmail.toLowerCase() == enseignantEmail.toLowerCase())
        .toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'dateCreation': dateCreation.toIso8601String(),
      'type': type.toString(),
      'year': year,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'enseignantEmails': enseignantEmails,
      'enseignantIds': enseignantIds,
      'groupeIds': groupeIds,
      'blocsCIFixes': blocsCIFixes.map((bloc) => bloc.toMap()).toList(),
      'ciMin': ciMin,
      'ciMax': ciMax,
    };
  }

  factory Tache.fromMap(String id, Map<String, dynamic> map) {
    final blocsData = map['blocsCIFixes'] as List<dynamic>? ?? [];
    final blocs = blocsData.map((b) => BlocCIFixe.fromMap(b as Map<String, dynamic>)).toList();

    return Tache(
      id: id,
      nom: map['nom'],
      dateCreation: DateTime.parse(map['dateCreation']),
      type: SessionType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      year: map['year'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      enseignantEmails: List<String>.from(map['enseignantEmails'] ?? []),
      enseignantIds: List<String>.from(map['enseignantIds'] ?? []),
      groupeIds: List<String>.from(map['groupeIds'] ?? []),
      blocsCIFixes: blocs,
      ciMin: map['ciMin']?.toDouble() ?? 38.0,
      ciMax: map['ciMax']?.toDouble() ?? 46.0,
    );
  }

  // Parser une liste d'emails depuis un texte
  static List<String> parseEmailsFromText(String text) {
    final emailRegex = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b');
    final matches = emailRegex.allMatches(text);
    return matches.map((m) => m.group(0)!.trim().toLowerCase()).toSet().toList();
  }

  Tache copyWith({
    String? nom,
    List<String>? enseignantEmails,
    List<String>? enseignantIds,
    List<String>? groupeIds,
    List<BlocCIFixe>? blocsCIFixes,
    double? ciMin,
    double? ciMax,
  }) {
    return Tache(
      id: id,
      nom: nom ?? this.nom,
      dateCreation: dateCreation,
      type: type,
      year: year,
      startDate: startDate,
      endDate: endDate,
      enseignantEmails: enseignantEmails ?? this.enseignantEmails,
      enseignantIds: enseignantIds ?? this.enseignantIds,
      groupeIds: groupeIds ?? this.groupeIds,
      blocsCIFixes: blocsCIFixes ?? this.blocsCIFixes,
      ciMin: ciMin ?? this.ciMin,
      ciMax: ciMax ?? this.ciMax,
    );
  }
}

enum SessionType {
  automne,
  hiver,
}

