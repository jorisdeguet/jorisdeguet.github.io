/// Représente un bloc de CI fixe attribué à un enseignant
/// (ex: PVRTT, coordination, etc.)
class BlocCIFixe {
  final String id;
  final String enseignantEmail; // Email de l'enseignant
  final String description; // Description du bloc (ex: "PVRTT", "Coordination")
  final double ci; // Valeur de CI du bloc

  BlocCIFixe({
    required this.id,
    required this.enseignantEmail,
    required this.description,
    required this.ci,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enseignantEmail': enseignantEmail,
      'description': description,
      'ci': ci,
    };
  }

  factory BlocCIFixe.fromMap(Map<String, dynamic> map) {
    return BlocCIFixe(
      id: map['id'] ?? '',
      enseignantEmail: map['enseignantEmail'] ?? '',
      description: map['description'] ?? '',
      ci: (map['ci'] as num?)?.toDouble() ?? 0.0,
    );
  }

  BlocCIFixe copyWith({
    String? id,
    String? enseignantEmail,
    String? description,
    double? ci,
  }) {
    return BlocCIFixe(
      id: id ?? this.id,
      enseignantEmail: enseignantEmail ?? this.enseignantEmail,
      description: description ?? this.description,
      ci: ci ?? this.ci,
    );
  }
}

