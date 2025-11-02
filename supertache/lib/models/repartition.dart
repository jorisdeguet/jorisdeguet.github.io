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
  final bool estAutomatique; // true si généré par l'algorithme génétique

  Repartition({
    required this.id,
    required this.tacheId,
    required this.nom,
    required this.dateCreation,
    required this.allocations,
    required this.groupesNonAlloues,
    required this.estValide,
    this.methode,
    this.estAutomatique = false,
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
      'estAutomatique': estAutomatique,
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
      estAutomatique: map['estAutomatique'] ?? false,
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
      estAutomatique: estAutomatique,
    );
  }

  /// Convertit la répartition en format String lisible
  /// Format: "prenom1(cours1-g1 cours1-g2 cours2-g3)prenom2(cours3-g1)"
  /// Les noms sont triés alphabétiquement, les groupes aussi
  String toHumanReadableString(
    Map<String, String> enseignantIdToName, // enseignantId -> "Prénom Nom" ou email prefix
    Map<String, String> groupeIdToLabel, // groupeId -> label complet ex: "3N5-1" ou "420-1B3-1010"
  ) {
    final parts = <String>[];

    // Trier les enseignants par nom
    final sortedEntries = allocations.entries.toList()
      ..sort((a, b) {
        final nameA = enseignantIdToName[a.key] ?? a.key;
        final nameB = enseignantIdToName[b.key] ?? b.key;
        return nameA.compareTo(nameB);
      });

    for (var entry in sortedEntries) {
      final enseignantId = entry.key;
      final groupeIds = entry.value;
      if (groupeIds.isEmpty) continue;

      // Obtenir le nom compact (prefix email si dispo)
      final raw = enseignantIdToName[enseignantId] ?? enseignantId;
      final firstToken = raw.contains('@') ? raw.split('@').first : raw.split(' ').first;
      final displayName = firstToken.toLowerCase();

      // Construire la liste label des groupes
      final groupes = <String>[];
      for (var groupeId in groupeIds) {
        final label = groupeIdToLabel[groupeId] ?? '???';
        groupes.add(label);
      }
      groupes.sort();
      parts.add('$displayName(${groupes.join(' ')})');
    }

    return parts.join('');
  }

  /// Parse un format String lisible et retourne les allocations
  /// Format: "prenom1(cours1-g1 cours1-g2)prenom2(cours3-g1)"
  static Map<String, List<String>>? parseHumanReadableString(
    String input,
    Map<String, String> nameToEnseignantId, // "prénom" ou "Prénom Nom" -> enseignantId
    Map<String, String> coursNumeroToGroupeId, // "3N5-1" -> groupeId
  ) {
    try {
      final allocations = <String, List<String>>{};
      final regex = RegExp(r'(\w+)\(([\w\s-]+)\)');
      final matches = regex.allMatches(input);

      for (var match in matches) {
        final name = match.group(1)!.toLowerCase();
        final groupesStr = match.group(2)!;

        // Trouver l'enseignant
        final enseignantId = nameToEnseignantId[name];
        if (enseignantId == null) continue;

        // Parser les groupes
        final groupes = <String>[];
        for (var groupe in groupesStr.split(' ')) {
          groupe = groupe.trim();
          if (groupe.isEmpty) continue;

          final groupeId = coursNumeroToGroupeId[groupe];
          if (groupeId != null) {
            groupes.add(groupeId);
          }
        }

        allocations[enseignantId] = groupes;
      }

      return allocations;
    } catch (e) {
      return null;
    }
  }

  /// Calcule un hash pour comparer les répartitions (diversité)
  String getSignature() {
    // Créer une signature unique basée sur les allocations
    final sortedKeys = allocations.keys.toList()..sort();
    final parts = <String>[];

    for (var key in sortedKeys) {
      final groupes = allocations[key]!.toList()..sort();
      parts.add('$key:${groupes.join(',')}');
    }

    return parts.join('|');
  }
}
