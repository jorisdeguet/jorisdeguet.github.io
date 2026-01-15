import 'dart:convert';

import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model_local/shared_key.dart';
import 'app_logger.dart';

/// Service pour stocker et récupérer les clés partagées localement.
///
/// Les clés sont stockées de manière sécurisée sur l'appareil.
/// Chaque conversation a sa propre clé identifiée par conversationId.
class KeyStorageService {
  static const String _keyPrefix = 'shared_key_';
  final _log = AppLogger();

  /// Sauvegarde une clé partagée pour une conversation
  Future<void> saveKey(String conversationId, SharedKey key, {String? lastKexId}) async {
     _log.i('KeyStorage', 'saveKey: conversationId=$conversationId, keyLength=${key.lengthInBits} bits, lastKexId=$lastKexId');

     try {
       final prefs = await SharedPreferences.getInstance();

       // Sérialiser la clé complète avec son historique
       final keyJson = key.toJson();

       // Ajouter lastKexId si fourni
       if (lastKexId != null) {
         keyJson['lastKexId'] = lastKexId;
       } else {
         // Préserver le lastKexId existant si présent
         final existingMeta = prefs.getString('${_keyPrefix}meta_$conversationId');
         if (existingMeta != null) {
           try {
             final existingJson = jsonDecode(existingMeta) as Map<String, dynamic>;
             keyJson['lastKexId'] = existingJson['lastKexId'];
           } catch (_) {}
         }
       }

       // Sauvegarder les données de la clé
       await prefs.setString('$_keyPrefix$conversationId', base64Encode(key.keyData));
       await prefs.setString('${_keyPrefix}meta_$conversationId', jsonEncode(keyJson));

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

       // Charger l'historique si présent
       KeyHistory? history;
       if (metadata['history'] != null) {
         history = KeyHistory.fromJson(metadata['history'] as Map<String, dynamic>);
       }

       final nextAvail = metadata['nextAvailableByte'] as int? ?? (metadata['startOffset'] as int? ?? 0);

       final key = SharedKey(
         id: metadata['id'] as String,
         keyData: Uint8List.fromList(keyData),
         peerIds: List<String>.from(metadata['peerIds'] as List),
         createdAt: DateTime.parse(metadata['createdAt'] as String),
         startOffset: metadata['startOffset'] as int? ?? 0,
         history: history,
         nextAvailableByte: nextAvail,
       );

       _log.i('KeyStorage', 'getKey: FOUND, ${key.lengthInBits} bits');
       return key;
     } catch (e) {
       _log.e('KeyStorage', 'getKey ERROR: $e');
       return null;
     }
   }

   /// Met à jour les octets utilisés pour une clé (startByte inclus, endByte exclusive)
   Future<void> updateUsedBytes(String conversationId, int startByte, int endByte) async {
     _log.i('KeyStorage', 'updateUsedBytes: $conversationId, $startByte-$endByte');

     try {
       final key = await getKey(conversationId);
       if (key == null) {
         _log.w('KeyStorage', 'updateUsedBytes: Key not found');
         return;
       }

       key.markBytesAsUsed(startByte, endByte);

       await saveKey(conversationId, key);
       _log.i('KeyStorage', 'updateUsedBytes: SUCCESS');
     } catch (e) {
       _log.e('KeyStorage', 'updateUsedBytes ERROR: $e');
     }
   }

   /// Wrapper de compatibilité: Met à jour les bits utilisés (converti en octets)
   Future<void> updateUsedBits(String conversationId, int startBit, int endBit) async {
     final startByte = (startBit / 8).floor();
     final endByte = ((endBit + 7) / 8).floor();
     return updateUsedBytes(conversationId, startByte, endByte);
   }

   /// Supprime une clé
   Future<void> deleteKey(String conversationId) async {
     _log.i('KeyStorage', 'deleteKey: $conversationId');

     try {
       final prefs = await SharedPreferences.getInstance();
       await prefs.remove('$_keyPrefix$conversationId');
       await prefs.remove('${_keyPrefix}meta_$conversationId');
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
