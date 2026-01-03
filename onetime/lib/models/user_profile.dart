/// Modèle représentant le profil d'un utilisateur authentifié.
class UserProfile {
  /// ID unique Firebase
  final String uid;
  
  /// Email de l'utilisateur
  final String? email;
  
  /// Nom d'affichage
  final String? displayName;
  
  /// URL de la photo de profil
  final String? photoUrl;
  
  /// Provider d'authentification utilisé
  final AppAuthProvider provider;
  
  /// Numéro de téléphone (si disponible)
  final String? phoneNumber;
  
  /// Date de création du compte
  final DateTime createdAt;
  
  /// Dernière connexion
  final DateTime lastSignIn;

  UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.provider,
    this.phoneNumber,
    required this.createdAt,
    required this.lastSignIn,
  });

  /// Nom à afficher (fallback sur email si pas de displayName)
  String get name => displayName ?? email?.split('@').first ?? 'Utilisateur';
  
  /// Initiales pour avatar
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'provider': provider.name,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.toIso8601String(),
      'lastSignIn': lastSignIn.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      provider: AppAuthProvider.values.byName(json['provider'] as String),
      phoneNumber: json['phoneNumber'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSignIn: DateTime.parse(json['lastSignIn'] as String),
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    DateTime? lastSignIn,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      provider: provider,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt,
      lastSignIn: lastSignIn ?? this.lastSignIn,
    );
  }
}

/// Providers d'authentification supportés
enum AppAuthProvider {
  google,
  facebook,
  apple,
  microsoft,
  github,
  email,
}

/// Extension pour obtenir des informations sur les providers
extension AppAuthProviderExtension on AppAuthProvider {
  String get displayName {
    switch (this) {
      case AppAuthProvider.google:
        return 'Google';
      case AppAuthProvider.facebook:
        return 'Facebook';
      case AppAuthProvider.apple:
        return 'Apple';
      case AppAuthProvider.microsoft:
        return 'Microsoft';
      case AppAuthProvider.github:
        return 'GitHub';
      case AppAuthProvider.email:
        return 'Email';
    }
  }

  String get iconAsset {
    switch (this) {
      case AppAuthProvider.google:
        return 'assets/icons/google.png';
      case AppAuthProvider.facebook:
        return 'assets/icons/facebook.png';
      case AppAuthProvider.apple:
        return 'assets/icons/apple.png';
      case AppAuthProvider.microsoft:
        return 'assets/icons/microsoft.png';
      case AppAuthProvider.github:
        return 'assets/icons/github.png';
      case AppAuthProvider.email:
        return 'assets/icons/email.png';
    }
  }
}
