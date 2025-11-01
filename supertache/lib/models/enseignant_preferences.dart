/// Modèle pour les préférences d'un enseignant
class EnseignantPreferences {
  final String enseignantId;
  final String enseignantEmail;
  
  // Préférences de cours
  final List<String> coursSouhaites; // Codes de cours (ex: "420-1B3")
  final List<String> coursEvites;
  
  // Préférences de collègues
  final List<String> colleguesSouhaites; // Emails ou IDs d'enseignants
  final List<String> colleguesEvites;
  
  // Plage CI préférée (optionnel, sinon utilise celle de la tâche)
  final double? ciMin;
  final double? ciMax;

  EnseignantPreferences({
    required this.enseignantId,
    required this.enseignantEmail,
    this.coursSouhaites = const [],
    this.coursEvites = const [],
    this.colleguesSouhaites = const [],
    this.colleguesEvites = const [],
    this.ciMin,
    this.ciMax,
  });

  Map<String, dynamic> toMap() {
    return {
      'enseignantId': enseignantId,
      'enseignantEmail': enseignantEmail,
      'coursSouhaites': coursSouhaites,
      'coursEvites': coursEvites,
      'colleguesSouhaites': colleguesSouhaites,
      'colleguesEvites': colleguesEvites,
      'ciMin': ciMin,
      'ciMax': ciMax,
    };
  }

  factory EnseignantPreferences.fromMap(Map<String, dynamic> map) {
    return EnseignantPreferences(
      enseignantId: map['enseignantId'] ?? '',
      enseignantEmail: map['enseignantEmail'] ?? '',
      coursSouhaites: List<String>.from(map['coursSouhaites'] ?? []),
      coursEvites: List<String>.from(map['coursEvites'] ?? []),
      colleguesSouhaites: List<String>.from(map['colleguesSouhaites'] ?? []),
      colleguesEvites: List<String>.from(map['colleguesEvites'] ?? []),
      ciMin: map['ciMin']?.toDouble(),
      ciMax: map['ciMax']?.toDouble(),
    );
  }

  EnseignantPreferences copyWith({
    List<String>? coursSouhaites,
    List<String>? coursEvites,
    List<String>? colleguesSouhaites,
    List<String>? colleguesEvites,
    double? ciMin,
    double? ciMax,
  }) {
    return EnseignantPreferences(
      enseignantId: enseignantId,
      enseignantEmail: enseignantEmail,
      coursSouhaites: coursSouhaites ?? this.coursSouhaites,
      coursEvites: coursEvites ?? this.coursEvites,
      colleguesSouhaites: colleguesSouhaites ?? this.colleguesSouhaites,
      colleguesEvites: colleguesEvites ?? this.colleguesEvites,
      ciMin: ciMin ?? this.ciMin,
      ciMax: ciMax ?? this.ciMax,
    );
  }
}
