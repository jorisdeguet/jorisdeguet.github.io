import 'package:cloud_firestore/cloud_firestore.dart';

class Repartition {
  final String id;
  final String tacheId;
  final String nom; // Nom de la répartition
  final DateTime dateCreation;
  final Map<String, List<String>> allocations; // enseignantId -> [groupeId1, groupeId2, ...]
  final List<String> groupesNonAlloues; // IDs des groupes non alloués
  final bool estValide;
  final String? methode; // 'manuelle' ou 'genetique'

  Repartition({
    required this.id,
    required this.tacheId,
    required this.nom,
    required this.dateCreation,
    required this.allocations,
    required this.groupesNonAlloues,
    required this.estValide,
    this.methode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tacheId': tacheId,
      'nom': nom,
      'dateCreation': Timestamp.fromDate(dateCreation),
      'allocations': allocations,
      'groupesNonAlloues': groupesNonAlloues,
      'estValide': estValide,
      'methode': methode,
    };
  }

  factory Repartition.fromMap(String id, Map<String, dynamic> map) {
    return Repartition(
      id: id,
      tacheId: map['tacheId'],
      nom: map['nom'],
      dateCreation: (map['dateCreation'] as Timestamp).toDate(),
      allocations: Map<String, List<String>>.from(
        (map['allocations'] as Map).map(
          (key, value) => MapEntry(key.toString(), List<String>.from(value)),
        ),
      ),
      groupesNonAlloues: List<String>.from(map['groupesNonAlloues'] ?? []),
      estValide: map['estValide'] ?? false,
      methode: map['methode'],
    );
  }

  Repartition copyWith({
    String? nom,
    Map<String, List<String>>? allocations,
    List<String>? groupesNonAlloues,
    bool? estValide,
    String? methode,
  }) {
    return Repartition(
      id: id,
      tacheId: tacheId,
      nom: nom ?? this.nom,
      dateCreation: dateCreation,
      allocations: allocations ?? this.allocations,
      groupesNonAlloues: groupesNonAlloues ?? this.groupesNonAlloues,
      estValide: estValide ?? this.estValide,
      methode: methode ?? this.methode,
    );
  }
}
