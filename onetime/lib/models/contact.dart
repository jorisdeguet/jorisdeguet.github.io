/// Modèle représentant un contact de l'application.
/// Le numéro de téléphone est l'identifiant principal pour contacter quelqu'un.
class Contact {
  /// ID unique du contact (basé sur le numéro de téléphone normalisé)
  final String id;
  
  /// Nom d'affichage
  final String displayName;
  
  /// Numéro de téléphone (identifiant principal)
  final String phoneNumber;

  /// URL de la photo
  final String? photoUrl;
  
  /// Le contact est-il un utilisateur de l'app ?
  final bool isAppUser;
  
  /// Date d'ajout aux contacts
  final DateTime addedAt;
  
  /// ID de la clé partagée avec ce contact (si existante)
  final String? sharedKeyId;

  Contact({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.photoUrl,
    this.isAppUser = false,
    DateTime? addedAt,
    this.sharedKeyId,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Crée un ID normalisé à partir du numéro de téléphone
  static String normalizePhoneNumber(String phone) {
    // Supprimer tous les espaces, tirets, parenthèses et autres caractères de formatage
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Vérifier si le numéro commence par +
    final hasPlus = cleaned.startsWith('+');

    // Garder uniquement les chiffres
    final digitsOnly = cleaned.replaceAll(RegExp(r'[^\d]'), '');

    // Si le numéro original commençait par +, le remettre
    if (hasPlus) {
      return '+$digitsOnly';
    }

    // Si commence par 00, remplacer par +
    if (digitsOnly.startsWith('00')) {
      return '+${digitsOnly.substring(2)}';
    }

    // Si commence par 0 (numéro local français), remplacer par +33
    if (digitsOnly.startsWith('0') && digitsOnly.length >= 10) {
      return '+33${digitsOnly.substring(1)}';
    }

    // Sinon, ajouter + devant (numéro international sans +)
    return '+$digitsOnly';
  }

  /// Numéro formaté pour affichage
  String get formattedPhoneNumber {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+') && cleaned.length > 10) {
      final country = cleaned.substring(0, cleaned.length - 9);
      final rest = cleaned.substring(cleaned.length - 9);
      return '$country ${rest.substring(0, 1)} ${rest.substring(1, 3)} ${rest.substring(3, 5)} ${rest.substring(5, 7)} ${rest.substring(7)}';
    }
    return phoneNumber;
  }

  /// Initiales pour avatar
  String get initials {
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.substring(0, displayName.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// A-t-on une clé partagée avec ce contact ?
  bool get hasSharedKey => sharedKeyId != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'isAppUser': isAppUser,
      'addedAt': addedAt.toIso8601String(),
      'sharedKeyId': sharedKeyId,
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      photoUrl: json['photoUrl'] as String?,
      isAppUser: json['isAppUser'] as bool? ?? false,
      addedAt: DateTime.parse(json['addedAt'] as String),
      sharedKeyId: json['sharedKeyId'] as String?,
    );
  }

  Contact copyWith({
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    bool? isAppUser,
    String? sharedKeyId,
  }) {
    return Contact(
      id: id,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isAppUser: isAppUser ?? this.isAppUser,
      addedAt: addedAt,
      sharedKeyId: sharedKeyId ?? this.sharedKeyId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Contact && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Contact du répertoire téléphone (avant import)
class PhoneContact {
  final String id;
  final String displayName;
  final List<String> phones;
  final String? photoUrl;

  PhoneContact({
    required this.id,
    required this.displayName,
    this.phones = const [],
    this.photoUrl,
  });

  /// Le contact a-t-il un numéro de téléphone ?
  bool get hasPhone => phones.isNotEmpty;

  /// Premier numéro de téléphone disponible
  String? get primaryPhone => phones.isNotEmpty ? phones.first : null;

  /// Convertit en Contact de l'app
  Contact? toAppContact({bool isAppUser = false}) {
    if (!hasPhone) return null;

    final normalizedPhone = Contact.normalizePhoneNumber(phones.first);
    return Contact(
      id: normalizedPhone, // Le numéro normalisé est l'ID
      displayName: displayName,
      phoneNumber: normalizedPhone,
      photoUrl: photoUrl,
      isAppUser: isAppUser,
    );
  }
}
