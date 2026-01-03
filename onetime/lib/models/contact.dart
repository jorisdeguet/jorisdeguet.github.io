/// Modèle représentant un contact de l'application.
class Contact {
  /// ID unique du contact
  final String id;
  
  /// Nom d'affichage
  final String displayName;
  
  /// Email du contact (pour retrouver sur Firebase)
  final String? email;
  
  /// Numéro de téléphone
  final String? phoneNumber;
  
  /// URL de la photo
  final String? photoUrl;
  
  /// UID Firebase si le contact est un utilisateur de l'app
  final String? firebaseUid;
  
  /// Le contact est-il un utilisateur de l'app ?
  final bool isAppUser;
  
  /// Date d'ajout aux contacts
  final DateTime addedAt;
  
  /// ID de la clé partagée avec ce contact (si existante)
  final String? sharedKeyId;

  Contact({
    required this.id,
    required this.displayName,
    this.email,
    this.phoneNumber,
    this.photoUrl,
    this.firebaseUid,
    this.isAppUser = false,
    DateTime? addedAt,
    this.sharedKeyId,
  }) : addedAt = addedAt ?? DateTime.now();

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
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'firebaseUid': firebaseUid,
      'isAppUser': isAppUser,
      'addedAt': addedAt.toIso8601String(),
      'sharedKeyId': sharedKeyId,
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      firebaseUid: json['firebaseUid'] as String?,
      isAppUser: json['isAppUser'] as bool? ?? false,
      addedAt: DateTime.parse(json['addedAt'] as String),
      sharedKeyId: json['sharedKeyId'] as String?,
    );
  }

  Contact copyWith({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    String? firebaseUid,
    bool? isAppUser,
    String? sharedKeyId,
  }) {
    return Contact(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      firebaseUid: firebaseUid ?? this.firebaseUid,
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
  final List<String> emails;
  final List<String> phones;
  final String? photoUrl;

  PhoneContact({
    required this.id,
    required this.displayName,
    this.emails = const [],
    this.phones = const [],
    this.photoUrl,
  });

  /// Convertit en Contact de l'app
  Contact toAppContact({String? firebaseUid, bool isAppUser = false}) {
    return Contact(
      id: 'phone_$id',
      displayName: displayName,
      email: emails.isNotEmpty ? emails.first : null,
      phoneNumber: phones.isNotEmpty ? phones.first : null,
      photoUrl: photoUrl,
      firebaseUid: firebaseUid,
      isAppUser: isAppUser,
    );
  }
}
