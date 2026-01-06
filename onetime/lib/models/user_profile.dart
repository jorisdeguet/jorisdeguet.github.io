/// Modèle représentant le profil d'un utilisateur authentifié.
/// Le numéro de téléphone est l'identifiant unique et principal.
class UserProfile {
  /// ID unique Firebase
  final String uid;
  
  /// Numéro de téléphone (identifiant principal)
  final String phoneNumber;

  /// Nom d'affichage optionnel
  final String? displayName;
  
  /// Date de création du compte
  final DateTime createdAt;
  
  /// Dernière connexion
  final DateTime lastSignIn;

  UserProfile({
    required this.uid,
    required this.phoneNumber,
    this.displayName,
    required this.createdAt,
    required this.lastSignIn,
  });

  /// Nom à afficher (fallback sur numéro formaté si pas de displayName)
  String get name => displayName ?? formattedPhoneNumber;

  /// Numéro formaté pour affichage
  String get formattedPhoneNumber {
    // Format: +33 6 12 34 56 78
    if (phoneNumber.length >= 10) {
      final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleaned.startsWith('+') && cleaned.length > 10) {
        final country = cleaned.substring(0, cleaned.length - 9);
        final rest = cleaned.substring(cleaned.length - 9);
        return '$country ${rest.substring(0, 1)} ${rest.substring(1, 3)} ${rest.substring(3, 5)} ${rest.substring(5, 7)} ${rest.substring(7)}';
      }
    }
    return phoneNumber;
  }

  /// Initiales pour avatar (basées sur les derniers chiffres du numéro)
  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName!.substring(0, displayName!.length >= 2 ? 2 : 1).toUpperCase();
    }
    // Utiliser les 2 derniers chiffres du numéro
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length >= 2) {
      return digits.substring(digits.length - 2);
    }
    return '?';
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'lastSignIn': lastSignIn.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      phoneNumber: json['phoneNumber'] as String,
      displayName: json['displayName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSignIn: DateTime.parse(json['lastSignIn'] as String),
    );
  }

  UserProfile copyWith({
    String? displayName,
    DateTime? lastSignIn,
  }) {
    return UserProfile(
      uid: uid,
      phoneNumber: phoneNumber,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      lastSignIn: lastSignIn ?? this.lastSignIn,
    );
  }
}
