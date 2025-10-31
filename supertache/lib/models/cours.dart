class Cours {
  final String id;
  final String code; // Ex: "420-1P6"
  final String codeSimple; // Ex: "1P6"
  final String titre; // Ex: "Introduction à la programmation"
  final int heuresTheorie; // Pondération théorie
  final int heuresLaboratoire; // Pondération laboratoire
  final List<String> sessions; // ["A", "H"] ou ["A-H"]

  Cours({
    required this.id,
    required this.code,
    required this.codeSimple,
    required this.titre,
    required this.heuresTheorie,
    required this.heuresLaboratoire,
    required this.sessions,
  });

  bool isOfferedInSession(SessionType session) {
    if (sessions.contains('A-H')) return true;
    if (session == SessionType.automne && sessions.contains('A')) return true;
    if (session == SessionType.hiver && sessions.contains('H')) return true;
    return false;
  }

  String get sessionsDisplay {
    if (sessions.contains('A-H')) return 'Automne et Hiver';
    if (sessions.contains('A-É')) return 'Automne et Été';
    final parts = <String>[];
    if (sessions.contains('A')) parts.add('Automne');
    if (sessions.contains('H')) parts.add('Hiver');
    if (sessions.contains('É')) parts.add('Été');
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'codeSimple': codeSimple,
      'titre': titre,
      'heuresTheorie': heuresTheorie,
      'heuresLaboratoire': heuresLaboratoire,
      'sessions': sessions,
    };
  }

  factory Cours.fromMap(String id, Map<String, dynamic> map) {
    return Cours(
      id: id,
      code: map['code'],
      codeSimple: map['codeSimple'],
      titre: map['titre'],
      heuresTheorie: map['heuresTheorie'],
      heuresLaboratoire: map['heuresLaboratoire'],
      sessions: List<String>.from(map['sessions'] ?? []),
    );
  }

  // Parser une ligne CSV
  // Format: Session, Code complet, Code simple, Titre, ..., Théorie, Labo
  static Cours? fromCSVLine(String line, int index) {
    try {
      final parts = line.split('\t').map((e) => e.trim()).toList();
      if (parts.length < 3) return null;

      // Extraire les données selon le format du tableau
      final sessionStr = parts[0]; // A, H, A-H, A-É
      final codeComplet = parts[1]; // 420-1P6
      final codeSimple = parts[2]; // 1P6
      final titre = parts.length > 3 ? parts[3] : '';
      
      // Les pondérations sont dans les dernières colonnes
      final theorie = parts.length > parts.length - 2 
          ? int.tryParse(parts[parts.length - 2]) ?? 0 
          : 0;
      final labo = parts.length > parts.length - 1 
          ? int.tryParse(parts[parts.length - 1]) ?? 0 
          : 0;

      // Parser les sessions
      final sessions = <String>[];
      if (sessionStr.contains('-')) {
        sessions.add(sessionStr); // A-H, A-É
      } else {
        for (var char in sessionStr.split('')) {
          if (char == 'A' || char == 'H' || char == 'É') {
            sessions.add(char);
          }
        }
      }

      if (titre.isEmpty || sessions.isEmpty) return null;

      return Cours(
        id: 'cours_$codeSimple',
        code: codeComplet,
        codeSimple: codeSimple,
        titre: titre,
        heuresTheorie: theorie,
        heuresLaboratoire: labo,
        sessions: sessions,
      );
    } catch (e) {
      return null;
    }
  }

  Cours copyWith({
    String? code,
    String? codeSimple,
    String? titre,
    int? heuresTheorie,
    int? heuresLaboratoire,
    List<String>? sessions,
  }) {
    return Cours(
      id: id,
      code: code ?? this.code,
      codeSimple: codeSimple ?? this.codeSimple,
      titre: titre ?? this.titre,
      heuresTheorie: heuresTheorie ?? this.heuresTheorie,
      heuresLaboratoire: heuresLaboratoire ?? this.heuresLaboratoire,
      sessions: sessions ?? this.sessions,
    );
  }
}

enum SessionType {
  automne,
  hiver,
}
