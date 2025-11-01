/// Modèle pour un vote préférentiel d'un enseignant sur des tâches générées
class TacheVote {
  final String enseignantId;
  final String enseignantEmail;
  final String tacheGenerationId; // ID de la génération de tâches
  
  // Liste ordonnée des IDs de tâches par préférence (du meilleur au pire)
  final List<String> tachesOrdonnees;
  
  final DateTime dateVote;

  TacheVote({
    required this.enseignantId,
    required this.enseignantEmail,
    required this.tacheGenerationId,
    required this.tachesOrdonnees,
    required this.dateVote,
  });

  Map<String, dynamic> toMap() {
    return {
      'enseignantId': enseignantId,
      'enseignantEmail': enseignantEmail,
      'tacheGenerationId': tacheGenerationId,
      'tachesOrdonnees': tachesOrdonnees,
      'dateVote': dateVote.toIso8601String(),
    };
  }

  factory TacheVote.fromMap(Map<String, dynamic> map) {
    return TacheVote(
      enseignantId: map['enseignantId'],
      enseignantEmail: map['enseignantEmail'],
      tacheGenerationId: map['tacheGenerationId'],
      tachesOrdonnees: List<String>.from(map['tachesOrdonnees']),
      dateVote: DateTime.parse(map['dateVote']),
    );
  }
}

/// Résultat de l'analyse de Condorcet
class CondorcetResult {
  final String? gagnantId; // null si pas de gagnant de Condorcet
  final Map<String, int> scores; // Score de chaque tâche
  final Map<String, Map<String, int>> comparaisons; // Matrice des comparaisons paires
  
  CondorcetResult({
    this.gagnantId,
    required this.scores,
    required this.comparaisons,
  });

  bool get hasGagnant => gagnantId != null;
}
