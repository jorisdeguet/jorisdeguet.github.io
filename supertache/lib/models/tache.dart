import 'groupe.dart';

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
  });

  double calculateCITotale(List<Groupe> groupes) {
    return groupes.fold<double>(0.0, (sum, groupe) => sum + groupe.ci);
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
    };
  }

  factory Tache.fromMap(String id, Map<String, dynamic> map) {
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
    );
  }
}

enum SessionType {
  automne,
  hiver,
}
