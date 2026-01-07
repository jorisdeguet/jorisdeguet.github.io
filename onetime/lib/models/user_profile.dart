/// Modèle représentant le profil d'un utilisateur.
/// L'identifiant unique est un UUID généré aléatoirement.
class UserProfile {
  /// ID unique (UUID v4)
  final String id;
  
  /// Date de création du compte
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.createdAt,
  });

  /// Initiales pour avatar (premiers caractères de l'ID)
  String get initials {
    if (id.length >= 2) {
      return id.substring(0, 2).toUpperCase();
    }
    return '?';
  }

  /// ID court pour affichage (8 premiers caractères)
  String get shortId => id.length > 8 ? id.substring(0, 8) : id;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  UserProfile copyWith() {
    return UserProfile(
      id: id,
      createdAt: createdAt,
    );
  }
}
