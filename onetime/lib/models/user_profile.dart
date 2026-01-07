/// Modèle représentant le profil d'un utilisateur.
/// L'identifiant unique est généré automatiquement, le pseudo est choisi par l'utilisateur.
class UserProfile {
  /// ID unique Firestore (généré automatiquement)
  final String id;
  
  /// Pseudo choisi par l'utilisateur
  final String pseudo;
  
  /// Date de création du compte
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.pseudo,
    required this.createdAt,
  });

  /// Initiales pour avatar
  String get initials {
    if (pseudo.isNotEmpty) {
      final parts = pseudo.split(' ');
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return pseudo.substring(0, pseudo.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '?';
  }

  /// ID court pour affichage
  String get shortId => id.length > 8 ? id.substring(0, 8) : id;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pseudo': pseudo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      pseudo: json['pseudo'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  UserProfile copyWith({
    String? pseudo,
  }) {
    return UserProfile(
      id: id,
      pseudo: pseudo ?? this.pseudo,
      createdAt: createdAt,
    );
  }
}
