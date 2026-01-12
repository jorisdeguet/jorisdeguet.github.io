import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shared_key.dart';
import 'app_logger.dart';

/// Service pour stocker et récupérer les clés partagées localement.
///
/// Les clés sont stockées de manière sécurisée sur l'appareil.
/// Chaque conversation a sa propre clé identifiée par conversationId.
class KeyStorageService {
  static const String _keyPrefix = 'shared_key_';
  static const String _usedBitsPrefix = 'used_bits_';
  final _log = AppLogger();

  /// Sauvegarde une clé partagée pour une conversation
  Future<void> saveKey(String conversationId, SharedKey key) async {
    _log.i('KeyStorage', 'saveKey: conversationId=$conversationId, keyLength=${key.lengthInBits} bits');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Préparer les valeurs à écrire
      final keyData = base64Encode(key.keyData);
      final metadata = jsonEncode({
        'id': key.id,
        'peerIds': key.peerIds,
        'createdAt': key.createdAt.toIso8601String(),
        'startOffset': key.startOffset,
      });
      final usedBitmapBase64 = base64Encode(key.usedBitmap);

      // Lire les valeurs actuelles et éviter d'écrire si tout est identique
      final existingKeyData = prefs.getString('$_keyPrefix$conversationId');
      final existingMeta = prefs.getString('${_keyPrefix}meta_$conversationId');
      final existingUsed = prefs.getString('$_usedBitsPrefix$conversationId');

      if (existingKeyData == keyData && existingMeta == metadata && existingUsed == usedBitmapBase64) {
        _log.i('KeyStorage', 'saveKey: SKIPPED (no changes)');
        return;
      }

      // Sauvegarder les données de la clé en base64
      await prefs.setString('$_keyPrefix$conversationId', keyData);

      // Sauvegarder les métadonnées
      await prefs.setString('${_keyPrefix}meta_$conversationId', metadata);

      // Sauvegarder le bitmap des bits utilisés
      await prefs.setString('$_usedBitsPrefix$conversationId', usedBitmapBase64);

      _log.i('KeyStorage', 'saveKey: SUCCESS');
    } catch (e) {
      _log.e('KeyStorage', 'saveKey ERROR: $e');
      rethrow;
    }
  }

  /// Récupère une clé partagée pour une conversation
  Future<SharedKey?> getKey(String conversationId) async {
    _log.i('KeyStorage', 'getKey: conversationId=$conversationId');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Récupérer les données de la clé
      final keyDataStr = prefs.getString('$_keyPrefix$conversationId');
      if (keyDataStr == null) {
        _log.i('KeyStorage', 'getKey: NOT FOUND');
        return null;
      }

      // Récupérer les métadonnées
      final metadataStr = prefs.getString('${_keyPrefix}meta_$conversationId');
      if (metadataStr == null) {
        _log.i('KeyStorage', 'getKey: metadata NOT FOUND');
        return null;
      }

      final keyData = base64Decode(keyDataStr);
      final metadata = jsonDecode(metadataStr) as Map<String, dynamic>;

      // Restaurer le bitmap des bits utilisés
      final usedBitsStr = prefs.getString('$_usedBitsPrefix$conversationId') ?? '';
      Uint8List? usedBitmap;
      
      if (usedBitsStr.isNotEmpty) {
        try {
          // Nouveau format: bitmap en base64
          usedBitmap = base64Decode(usedBitsStr);
        } catch (e) {
          // Ancien format: liste de ranges "start-end;start-end"
          // Créer un bitmap vide et marquer les bits utilisés
          final bitmapSize = (keyData.length * 8 + 7) ~/ 8;
          usedBitmap = Uint8List(bitmapSize);
          
          final usedRanges = usedBitsStr.split(';');
          for (final range in usedRanges) {
            if (range.isNotEmpty) {
              final parts = range.split('-');
              if (parts.length == 2) {
                final start = int.tryParse(parts[0]);
                final end = int.tryParse(parts[1]);
                if (start != null && end != null) {
                  // Marquer les bits dans le bitmap
                  for (int bit = start; bit <= end; bit++) {
                    final byteIndex = bit ~/ 8;
                    final bitOffset = bit % 8;
                    if (byteIndex < usedBitmap.length) {
                      usedBitmap[byteIndex] |= (1 << bitOffset);
                    }
                  }
                }
              }
            }
          }
        }
      }

      final key = SharedKey(
        id: metadata['id'] as String,
        keyData: Uint8List.fromList(keyData),
        peerIds: List<String>.from(metadata['peerIds'] as List),
        createdAt: DateTime.parse(metadata['createdAt'] as String),
        usedBitmap: usedBitmap,
        startOffset: metadata['startOffset'] as int? ?? 0,
      );

      _log.i('KeyStorage', 'getKey: FOUND, ${key.lengthInBits} bits');
      return key;
    } catch (e) {
      _log.e('KeyStorage', 'getKey ERROR: $e');
      return null;
    }
  }

  /// Met à jour les bits utilisés pour une clé
  Future<void> updateUsedBits(String conversationId, int startBit, int endBit) async {
    _log.i('KeyStorage', 'updateUsedBits: $conversationId, $startBit-$endBit');

    try {
      // Charger la clé existante
      final key = await getKey(conversationId);
      if (key == null) {
        _log.w('KeyStorage', 'updateUsedBits: Key not found');
        return;
      }

      // Marquer les bits comme utilisés
      key.markBitsAsUsed(startBit, endBit);

      // Sauvegarder la clé mise à jour avec le nouveau bitmap
      await saveKey(conversationId, key);
      
      _log.i('KeyStorage', 'updateUsedBits: SUCCESS');
    } catch (e) {
      _log.e('KeyStorage', 'updateUsedBits ERROR: $e');
    }
  }

  /// Supprime une clé
  Future<void> deleteKey(String conversationId) async {
    _log.i('KeyStorage', 'deleteKey: $conversationId');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPrefix$conversationId');
      await prefs.remove('${_keyPrefix}meta_$conversationId');
      await prefs.remove('$_usedBitsPrefix$conversationId');
      _log.i('KeyStorage', 'deleteKey: SUCCESS');
    } catch (e) {
      _log.e('KeyStorage', 'deleteKey ERROR: $e');
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
