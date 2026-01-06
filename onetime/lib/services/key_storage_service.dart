import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shared_key.dart';

/// Service pour stocker et récupérer les clés partagées localement.
///
/// Les clés sont stockées de manière sécurisée sur l'appareil.
/// Chaque conversation a sa propre clé identifiée par conversationId.
class KeyStorageService {
  static const String _keyPrefix = 'shared_key_';
  static const String _usedBitsPrefix = 'used_bits_';

  /// Sauvegarde une clé partagée pour une conversation
  Future<void> saveKey(String conversationId, SharedKey key) async {
    debugPrint('[KeyStorageService] saveKey: conversationId=$conversationId, keyLength=${key.lengthInBits} bits');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Sauvegarder les données de la clé en base64
      final keyData = base64Encode(key.keyData);
      await prefs.setString('$_keyPrefix$conversationId', keyData);

      // Sauvegarder les métadonnées
      final metadata = {
        'id': key.id,
        'peerIds': key.peerIds,
        'createdAt': key.createdAt.toIso8601String(),
        'conversationName': key.conversationName,
      };
      await prefs.setString('${_keyPrefix}meta_$conversationId', jsonEncode(metadata));

      // Sauvegarder les bits utilisés (initialement vide)
      await prefs.setString('$_usedBitsPrefix$conversationId', '');

      debugPrint('[KeyStorageService] saveKey: SUCCESS');
    } catch (e) {
      debugPrint('[KeyStorageService] saveKey ERROR: $e');
      rethrow;
    }
  }

  /// Récupère une clé partagée pour une conversation
  Future<SharedKey?> getKey(String conversationId) async {
    debugPrint('[KeyStorageService] getKey: conversationId=$conversationId');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Récupérer les données de la clé
      final keyDataStr = prefs.getString('$_keyPrefix$conversationId');
      if (keyDataStr == null) {
        debugPrint('[KeyStorageService] getKey: NOT FOUND');
        return null;
      }

      // Récupérer les métadonnées
      final metadataStr = prefs.getString('${_keyPrefix}meta_$conversationId');
      if (metadataStr == null) {
        debugPrint('[KeyStorageService] getKey: metadata NOT FOUND');
        return null;
      }

      final keyData = base64Decode(keyDataStr);
      final metadata = jsonDecode(metadataStr) as Map<String, dynamic>;

      final key = SharedKey(
        id: metadata['id'] as String,
        keyData: Uint8List.fromList(keyData),
        peerIds: List<String>.from(metadata['peerIds'] as List),
        createdAt: DateTime.parse(metadata['createdAt'] as String),
        conversationName: metadata['conversationName'] as String?,
      );

      // Restaurer les bits utilisés
      final usedBitsStr = prefs.getString('$_usedBitsPrefix$conversationId') ?? '';
      if (usedBitsStr.isNotEmpty) {
        final usedRanges = usedBitsStr.split(';');
        for (final range in usedRanges) {
          if (range.isNotEmpty) {
            final parts = range.split('-');
            if (parts.length == 2) {
              final start = int.tryParse(parts[0]);
              final end = int.tryParse(parts[1]);
              if (start != null && end != null) {
                key.markBitsAsUsed(start, end);
              }
            }
          }
        }
      }

      debugPrint('[KeyStorageService] getKey: FOUND, ${key.lengthInBits} bits');
      return key;
    } catch (e) {
      debugPrint('[KeyStorageService] getKey ERROR: $e');
      return null;
    }
  }

  /// Met à jour les bits utilisés pour une clé
  Future<void> updateUsedBits(String conversationId, int startBit, int endBit) async {
    debugPrint('[KeyStorageService] updateUsedBits: $conversationId, $startBit-$endBit');

    try {
      final prefs = await SharedPreferences.getInstance();

      final currentStr = prefs.getString('$_usedBitsPrefix$conversationId') ?? '';
      final newRange = '$startBit-$endBit';
      final updated = currentStr.isEmpty ? newRange : '$currentStr;$newRange';

      await prefs.setString('$_usedBitsPrefix$conversationId', updated);
      debugPrint('[KeyStorageService] updateUsedBits: SUCCESS');
    } catch (e) {
      debugPrint('[KeyStorageService] updateUsedBits ERROR: $e');
    }
  }

  /// Supprime une clé
  Future<void> deleteKey(String conversationId) async {
    debugPrint('[KeyStorageService] deleteKey: $conversationId');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPrefix$conversationId');
      await prefs.remove('${_keyPrefix}meta_$conversationId');
      await prefs.remove('$_usedBitsPrefix$conversationId');
      debugPrint('[KeyStorageService] deleteKey: SUCCESS');
    } catch (e) {
      debugPrint('[KeyStorageService] deleteKey ERROR: $e');
    }
  }

  /// Vérifie si une clé existe pour une conversation
  Future<bool> hasKey(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_keyPrefix$conversationId');
  }

  /// Liste toutes les conversations qui ont une clé
  Future<List<String>> listConversationsWithKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    return keys
        .where((k) => k.startsWith(_keyPrefix) && !k.contains('meta_'))
        .map((k) => k.substring(_keyPrefix.length))
        .toList();
  }
}

