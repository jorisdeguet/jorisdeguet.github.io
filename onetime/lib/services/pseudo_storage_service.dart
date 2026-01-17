import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

/// Service pour stocker localement les pseudos des utilisateurs.
///
/// Les pseudos sont stockés uniquement sur le téléphone et jamais en clair sur Firestore.
/// Ils sont échangés de manière chiffrée au début de chaque conversation.
class PseudoStorageService {
  static const String _pseudosKey = 'local_pseudos';
  static const String _myPseudoKey = 'my_pseudo';

  /// Cache en mémoire des pseudos
  Map<String, String>? _pseudosCache;
  final _log = AppLogger();

  /// Récupère le pseudo local de l'utilisateur actuel
  Future<String?> getMyPseudo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_myPseudoKey);
  }

  /// Définit le pseudo local de l'utilisateur actuel
  Future<void> setMyPseudo(String pseudo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_myPseudoKey, pseudo);
    _log.i('PseudoStorage', 'My pseudo set: $pseudo');
  }

  /// Charge tous les pseudos depuis le stockage local
  Future<Map<String, String>> loadPseudos() async {
    if (_pseudosCache != null) return _pseudosCache!;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_pseudosKey);

    if (jsonStr == null) {
      _pseudosCache = {};
      return _pseudosCache!;
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      _pseudosCache = decoded.map((k, v) => MapEntry(k, v.toString()));
      return _pseudosCache!;
    } catch (e) {
      _log.e('PseudoStorage', 'Error loading pseudos: $e');
      _pseudosCache = {};
      return _pseudosCache!;
    }
  }

  /// Sauvegarde tous les pseudos
  Future<void> _savePseudos() async {
    if (_pseudosCache == null) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_pseudosCache);
    await prefs.setString(_pseudosKey, jsonStr);
  }

  /// Récupère le pseudo d'un utilisateur par son ID
  Future<String?> getPseudo(String oderId) async {
    final pseudos = await loadPseudos();
    return pseudos[oderId];
  }

  /// Définit le pseudo d'un utilisateur
  Future<void> setPseudo(String oderId, String pseudo) async {
    await loadPseudos();
    
    // Ne rien faire si le pseudo n'a pas changé
    if (_pseudosCache![oderId] == pseudo) {
      return;
    }
    
    _pseudosCache![oderId] = pseudo;
    await _savePseudos();
    _log.i('PseudoStorage', 'Pseudo set for $oderId: $pseudo');
  }

  /// Définit plusieurs pseudos en une fois
  Future<void> setPseudos(Map<String, String> pseudos) async {
    await loadPseudos();
    _pseudosCache!.addAll(pseudos);
    await _savePseudos();
    _log.i('PseudoStorage', 'Pseudos set: ${pseudos.keys.join(", ")}');
  }

  /// Supprime le pseudo d'un utilisateur
  Future<void> removePseudo(String oderId) async {
    await loadPseudos();
    _pseudosCache!.remove(oderId);
    await _savePseudos();
  }

  /// Retourne un nom d'affichage pour un ID utilisateur
  /// Si un pseudo est connu, le retourne, sinon retourne une version courte de l'ID
  Future<String> getDisplayName(String userId) async {
    final pseudo = await getPseudo(userId);
    if (pseudo != null && pseudo.isNotEmpty) {
      return pseudo;
    }
    // Retourner les derniers chiffres du numéro de téléphone
    if (userId.length > 4) {
      return '...${userId.substring(userId.length - 4)}';
    }
    return userId;
  }

  /// Retourne les noms d'affichage pour plusieurs IDs
  Future<Map<String, String>> getDisplayNames(List<String> oderIds) async {
    final pseudos = await loadPseudos();
    final result = <String, String>{};

    for (final oderId in oderIds) {
      if (pseudos.containsKey(oderId) && pseudos[oderId]!.isNotEmpty) {
        result[oderId] = pseudos[oderId]!;
      } else if (oderId.length > 4) {
        result[oderId] = '...${oderId.substring(oderId.length - 4)}';
      } else {
        result[oderId] = oderId;
      }
    }

    return result;
  }

  /// Efface le cache en mémoire (pour forcer un rechargement)
  void clearCache() {
    _pseudosCache = null;
  }
}

/// Type de message spécial pour l'échange de pseudo
class PseudoExchangeMessage {
  final String oderId;
  final String pseudo;

  PseudoExchangeMessage({
    required this.oderId,
    required this.pseudo,
  });

  /// Sérialise pour chiffrement
  String toJson() {
    return jsonEncode({
      'type': 'pseudo_exchange',
      'userId': oderId,
      'pseudo': pseudo,
    });
  }

  /// Désérialise après déchiffrement
  static PseudoExchangeMessage? fromJson(String jsonStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      if (data['type'] != 'pseudo_exchange') return null;

      return PseudoExchangeMessage(
        oderId: data['userId'] as String,
        pseudo: data['pseudo'] as String,
      );
    } catch (e) {
      return null;
    }
  }

  /// Vérifie si un message déchiffré est un échange de pseudo
  static bool isPseudoExchange(String decryptedContent) {
    try {
      final data = jsonDecode(decryptedContent);
      return data['type'] == 'pseudo_exchange';
    } catch (e) {
      return false;
    }
  }
}
