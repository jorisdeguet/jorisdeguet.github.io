class Enseignant {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String? photoUrl;

  Enseignant({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    this.photoUrl,
  });

  String get nomComplet => '$prenom $nom';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'photoUrl': photoUrl,
    };
  }

  factory Enseignant.fromMap(String id, Map<String, dynamic> map) {
    return Enseignant(
      id: id,
      nom: map['nom'],
      prenom: map['prenom'],
      email: map['email'],
      photoUrl: map['photoUrl'],
    );
  }
}
