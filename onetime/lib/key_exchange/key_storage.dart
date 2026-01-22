import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:onetime/services/app_logger.dart';
import 'package:onetime/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../key_exchange/key_history.dart';
import '../key_exchange/shared_key.dart';

/// Service pour stocker et récupérer les clés partagées localement.
///
/// Les clés sont stockées de manière sécurisée sur l'appareil.
/// Chaque conversation a sa propre clé identifiée par conversationId.
class KeyStorage {
  static const String _keyPrefix = 'shared_key_';
  final _log = AppLogger();

  // Optional local user id used to report key debug info to Firestore
  final String _localUserId;
  final ConversationService? _conversationService;

  KeyStorage({String? localUserId})
      : _localUserId = localUserId ?? '',
        _conversationService = localUserId != null ? ConversationService(localUserId: localUserId) : null;

  /// Sauvegarde une clé partagée pour une conversation
  Future<void> saveKey(String conversationId, SharedKey key) async {
     _log.i('KeyStorage', 'saveKey: conversationId=$conversationId, keyLength=${key.lengthInBits} bits');

     try {
       final prefs = await SharedPreferences.getInstance();

       // Sérialiser la clé complète avec son historique
       final keyJson = key.toJson();

       // Ensure the stored id is the conversationId (legacy keys may contain other ids)
       keyJson['id'] = conversationId;

       // Sauvegarder les données de la clé
       await prefs.setString('$_keyPrefix$conversationId', base64Encode(key.keyData));
       await prefs.setString('${_keyPrefix}meta_$conversationId', jsonEncode(keyJson));

       _log.i('KeyStorage', 'saveKey: SUCCESS');

       // Update Firestore debug info if possible
       try {
         if (_conversationService != null && _localUserId.isNotEmpty) {
           final info = {
             'history': key.history.toJson(),
             'interval': key.interval.toJson(),
             'nextAvailableByte': key.nextAvailableByte,
             'startOffset': key.startOffset,
           };
           await _conversationService.updateKeyDebugInfo(
             conversationId: conversationId,
             userId: _localUserId,
             info: info,
           );
           _log.d('KeyStorage', 'Firestore keyDebugInfo updated after saveKey');
         }
       } catch (e) {
         _log.w('KeyStorage', 'Could not update Firestore keyDebugInfo: $e');
       }
     } catch (e) {
       _log.e('KeyStorage', 'saveKey ERROR: $e');
       rethrow;
     }
   }

   /// Récupère une clé partagée pour une conversation
   Future<SharedKey> getKey(String conversationId) async {
     _log.i('KeyStorage', 'getKey: conversationId=$conversationId');

     try {
       final prefs = await SharedPreferences.getInstance();

       // Récupérer les données de la clé
       final keyDataStr = prefs.getString('$_keyPrefix$conversationId');
       if (keyDataStr == null) {
         _log.i('KeyStorage', 'getKey: NOT FOUND');
         throw Exception('Key not found for conversation $conversationId');
       }

       // Récupérer les métadonnées
       final metadataStr = prefs.getString('${_keyPrefix}meta_$conversationId');
       if (metadataStr == null) {
         _log.i('KeyStorage', 'getKey: metadata NOT FOUND');
         throw Exception('Key metadata not found for conversation $conversationId');
       }

       final keyData = base64Decode(keyDataStr);
       final metadata = jsonDecode(metadataStr) as Map<String, dynamic>;

       // Charger l'historique si présent
       KeyHistory? history;
       if (metadata['history'] != null) {
         history = KeyHistory.fromJson(metadata['history'] as Map<String, dynamic>);
       }

       final nextAvail = metadata['nextAvailableByte'] as int? ?? (metadata['startOffset'] as int? ?? 0);

       // Force the key id to be the conversationId to avoid mismatches
       final key = SharedKey(
         id: conversationId,
         keyData: Uint8List.fromList(keyData),
         peerIds: List<String>.from(metadata['peerIds'] as List),
         createdAt: DateTime.parse(metadata['createdAt'] as String),
         startOffset: metadata['startOffset'] as int? ?? 0,
         history: history,
         nextAvailableByte: nextAvail,
       );

       _log.i('KeyStorage', 'getKey: FOUND, ${key.lengthInBits} bits');

       // Log history and push to Firestore for debugging
       try {
         final histStr = key.history.format();
         _log.i('KeyStorage', 'Key history:\n$histStr');

         if (_conversationService != null && _localUserId.isNotEmpty) {
           final info = {
             'history': key.history.toJson(),
             'interval': key.interval.toJson(),
             'nextAvailableByte': key.nextAvailableByte,
             'startOffset': key.startOffset,
           };
           await _conversationService.updateKeyDebugInfo(
             conversationId: conversationId,
             userId: _localUserId,
             info: info,
           );
           _log.d('KeyStorage', 'Firestore keyDebugInfo updated after getKey');
         }
       } catch (e) {
         _log.w('KeyStorage', 'Could not push history to Firestore: $e');
       }

       return key;
     } catch (e) {
       _log.e('KeyStorage', 'getKey ERROR: $e');
       rethrow;
     }
   }

   /// Met à jour les octets utilisés pour une clé (startByte inclus, endByte exclusive)
   Future<void> updateUsedBytes(String conversationId, int startByte, int endByte) async {
     _log.i('KeyStorage', 'updateUsedBytes: $conversationId, $startByte-$endByte');

     try {
       final key = await getKey(conversationId);
       key.markBytesAsUsed(startByte, endByte);
       await saveKey(conversationId, key);
       _log.i('KeyStorage', 'updateUsedBytes: SUCCESS');
     } catch (e) {
       _log.e('KeyStorage', 'updateUsedBytes ERROR: $e');
     }
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

  Future<int> getTotalUsedBytes() async {
    int totalUsed = 0;
    final conversationIds = await listConversationsWithKeys();
    for (final convoId in conversationIds) {
      final key = await getKey(convoId);
      totalUsed += key.keyData.length;
    }
    return totalUsed;
  }
 }
