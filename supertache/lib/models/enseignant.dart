class Enseignant {
  final String id;
  final String email;
  final String? photoUrl;

  Enseignant({
    required this.id,
    required this.email,
    this.photoUrl,
  });

  String get displayName => email.split('@')[0];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'photoUrl': photoUrl,
    };
  }

  factory Enseignant.fromMap(String id, Map<String, dynamic> map) {
    return Enseignant(
      id: id,
      email: map['email'],
      photoUrl: map['photoUrl'],
    );
  }
}
