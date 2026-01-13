import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

/// Service pour stocker les pseudos par conversation
class ConversationPseudoService {
  static const String _prefix = 'conv_pseudos_';

  final _pseudoUpdateController = StreamController<String>.broadcast();
  final _log = AppLogger();

  /// Stream des mises à jour de pseudos (renvoie l'ID de la conversation modifiée)
  Stream<String> get pseudoUpdates => _pseudoUpdateController.stream;

  /// Sauvegarde un pseudo pour un utilisateur dans une conversation
  Future<void> setPseudo(String conversationId, String userId, String pseudo) async {
    _log.d('ConvPseudo', 'Setting pseudo for $userId in $conversationId: $pseudo');

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$conversationId';
      
      // Charger les pseudos existants
      final existing = await getPseudos(conversationId);
      
      // Vérifier si changement
      if (existing[userId] == pseudo) return;
      
      existing[userId] = pseudo;
      
      // Sauvegarder
      await prefs.setString(key, jsonEncode(existing));
      
      // Notifier
      _pseudoUpdateController.add(conversationId);
      
      _log.i('ConvPseudo', 'Pseudo saved successfully');
    } catch (e) {
      _log.e('ConvPseudo', 'Error saving pseudo: $e');
    }
  }

  /// Récupère tous les pseudos d'une conversation
  Future<Map<String, String>> getPseudos(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$conversationId';
      final data = prefs.getString(key);
      
      if (data == null) return {};
      
      final Map<String, dynamic> json = jsonDecode(data);
      return json.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      _log.e('ConvPseudo', 'Error getting pseudos: $e');
      return {};
    }
  }

  /// Récupère le pseudo d'un utilisateur dans une conversation
  Future<String?> getPseudo(String conversationId, String userId) async {
    final pseudos = await getPseudos(conversationId);
    return pseudos[userId];
  }

  /// Supprime tous les pseudos d'une conversation
  Future<void> deletePseudos(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$conversationId';
      await prefs.remove(key);
      _log.i('ConvPseudo', 'Pseudos deleted for conversation $conversationId');
    } catch (e) {
      _log.e('ConvPseudo', 'Error deleting pseudos: $e');
    }
  }

  /// Supprime tous les pseudos de toutes les conversations
  Future<void> deleteAllPseudos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_prefix)) {
          await prefs.remove(key);
        }
      }
      
      _log.i('ConvPseudo', 'All pseudos deleted');
    } catch (e) {
      _log.e('ConvPseudo', 'Error deleting all pseudos: $e');
    }
  }
}
