class Groupe {
  final String id;
  final String cours; // Nom du cours (ex: "Programmation I")
  final String numeroGroupe; // Numéro du groupe (ex: "1010", "1020")
  final int nombreEtudiants;
  final double heuresTheorie;
  final double heuresPratique;
  final String tacheId; // ID de la tâche à laquelle appartient ce groupe

  Groupe({
    required this.id,
    required this.cours,
    required this.numeroGroupe,
    required this.nombreEtudiants,
    required this.heuresTheorie,
    required this.heuresPratique,
    required this.tacheId,
  });

  String get nomComplet => '$cours - $numeroGroupe';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cours': cours,
      'numeroGroupe': numeroGroupe,
      'nombreEtudiants': nombreEtudiants,
      'heuresTheorie': heuresTheorie,
      'heuresPratique': heuresPratique,
      'tacheId': tacheId,
    };
  }

  factory Groupe.fromMap(String id, Map<String, dynamic> map) {
    return Groupe(
      id: id,
      cours: map['cours'],
      numeroGroupe: map['numeroGroupe'],
      nombreEtudiants: map['nombreEtudiants'],
      heuresTheorie: (map['heuresTheorie'] as num).toDouble(),
      heuresPratique: (map['heuresPratique'] as num).toDouble(),
      tacheId: map['tacheId'],
    );
  }

  // Parser une ligne CSV
  static Groupe? fromCSVLine(String line, String tacheId, int index) {
    try {
      final parts = line.split(',').map((e) => e.trim()).toList();
      if (parts.length < 5) return null;

      return Groupe(
        id: '${tacheId}_groupe_$index',
        cours: parts[0],
        numeroGroupe: parts[1],
        nombreEtudiants: int.parse(parts[2]),
        heuresTheorie: double.parse(parts[3]),
        heuresPratique: double.parse(parts[4]),
        tacheId: tacheId,
      );
    } catch (e) {
      return null;
    }
  }
}
