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
  /// kexContributions: optional list of { 'kexId': string, 'startBit': int, 'endBit': int }
  Future<void> saveKey(String conversationId, SharedKey key, {String? lastKexId, List<Map<String, dynamic>>? kexContributions}) async {
     _log.i('KeyStorage', 'saveKey: conversationId=$conversationId, keyLength=${key.lengthInBits} bits, lastKexId=$lastKexId, contributions=${kexContributions?.length ?? 0}');

     try {
       // Prepare values to write (we will compute effective lastKexId after reading existing meta)
       final keyData = base64Encode(key.keyData);
       final nextAvailable = key.nextAvailableByte;

       // Reopen prefs and re-check to avoid redundant write after pending save
       final prefs = await SharedPreferences.getInstance();
       final existingKeyData = prefs.getString('$_keyPrefix$conversationId');
       final existingMeta = prefs.getString('${_keyPrefix}meta_$conversationId');

       if (existingKeyData == keyData && existingMeta != null) {
         bool peersEqual = false;
         bool sameKex = false;
         bool contributionsEqual = false;
         try {
           final Map<String, dynamic> existingMetaJson = jsonDecode(existingMeta) as Map<String, dynamic>;

           final existingLastKex = existingMetaJson['lastKexId'] as String?;
           sameKex = (existingLastKex == lastKexId);

           final existingPeerIds = (existingMetaJson['peerIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
           final newPeerIds = List<String>.from(key.peerIds);
           existingPeerIds.sort();
           newPeerIds.sort();
           peersEqual = listEquals(existingPeerIds, newPeerIds);

           final existingContrib = existingMetaJson['kexContributions'] as List?;
           if (existingContrib == null && kexContributions == null) {
             contributionsEqual = true;
           } else if (existingContrib != null && kexContributions != null) {
             List<Map<String, dynamic>> a = existingContrib.map((e) => Map<String, dynamic>.from(e as Map)).toList();
             List<Map<String, dynamic>> b = kexContributions.map((e) => Map<String, dynamic>.from(e)).toList();
             a.sort((x, y) => (x['kexId'] as String).compareTo(y['kexId'] as String));
             b.sort((x, y) => (x['kexId'] as String).compareTo(y['kexId'] as String));
             contributionsEqual = const DeepCollectionEquality().equals(a, b);
           }

           final existingNextAvail = existingMetaJson['nextAvailableByte'] as int? ?? key.startOffset;

           if (peersEqual && sameKex && contributionsEqual && existingNextAvail == nextAvailable) {
             _log.i('KeyStorage', 'saveKey: SKIPPED (no changes to key bytes/peers/nextAvailableByte and same lastKexId and contributions)');
             return;
           }
         } catch (_) {
           // ignore and proceed to save
         }
       }

       // Determine effective lastKexId: prefer provided lastKexId, otherwise preserve existing value
       String? effectiveLastKex;
       if (lastKexId != null) {
         effectiveLastKex = lastKexId;
       } else if (existingMeta != null) {
         try {
           final Map<String, dynamic> existingMetaJson = jsonDecode(existingMeta) as Map<String, dynamic>;
           effectiveLastKex = existingMetaJson['lastKexId'] as String?;
         } catch (_) {
           effectiveLastKex = null;
         }
       }

       // Determine effective contributions: merge existing contributions with provided ones
       List<Map<String, dynamic>>? effectiveContrib;
       if (kexContributions != null && kexContributions.isNotEmpty) {
         effectiveContrib = kexContributions.map((e) => Map<String, dynamic>.from(e)).toList();
       } else if (existingMeta != null) {
         try {
           final Map<String, dynamic> existingMetaJson = jsonDecode(existingMeta) as Map<String, dynamic>;
           final existingContrib = existingMetaJson['kexContributions'] as List?;
           if (existingContrib != null) {
             effectiveContrib = existingContrib.map((e) => Map<String, dynamic>.from(e as Map)).toList();
           }
         } catch (_) {
           effectiveContrib = null;
         }
       }

       final prefsInner = await SharedPreferences.getInstance();

       // If there's an existing key and the new keyData begins with the existing bytes,
       // treat this as an extension and merge metadata instead of blindly overwriting.
       if (existingKeyData != null) {
         try {
           final existingBytes = base64Decode(existingKeyData);
           final newBytes = base64Decode(keyData);

           _log.d('KeyStorage', 'Extension check: existing=${existingBytes.length} bytes, new=${newBytes.length} bytes');

           bool isExtension = newBytes.length > existingBytes.length;
           bool prefixMatches = false;
           if (isExtension) {
             prefixMatches = true;
             for (int i = 0; i < existingBytes.length; i++) {
               if (existingBytes[i] != newBytes[i]) {
                 prefixMatches = false;
                 break;
               }
             }
             _log.d('KeyStorage', 'Extension prefixMatches=$prefixMatches for ${existingBytes.length} bytes');
             isExtension = prefixMatches;
           } else {
             _log.d('KeyStorage', 'Extension check: new is not longer than existing (not an extension)');
           }

           if (isExtension) {
             _log.i('KeyStorage', 'Detected key extension; merging metadata');

             final existingMetaJson = existingMeta != null ? jsonDecode(existingMeta) as Map<String, dynamic> : null;
             final existingPeerIds = existingMetaJson != null
                 ? (existingMetaJson['peerIds'] as List?)?.map((e) => e.toString()).toList() ?? []
                 : [];
             final combinedPeers = {...existingPeerIds, ...key.peerIds}.toList()..sort();

             // Preserve createdAt from existing meta when extending
             String createdAtStr = key.createdAt.toIso8601String();
             if (existingMetaJson != null && existingMetaJson['createdAt'] != null) {
               createdAtStr = existingMetaJson['createdAt'] as String;
             }

             // Preserve nextAvailableByte from existing metadata if present, otherwise use key.nextAvailableByte
             final mergedNextAvailable = existingMetaJson != null
                 ? (existingMetaJson['nextAvailableByte'] as int? ?? key.nextAvailableByte)
                 : key.nextAvailableByte;

             // Merge kexContributions: keep existing and expand with provided
             final Map<String, Map<String, dynamic>> contribById = {};
             if (existingMetaJson != null && existingMetaJson['kexContributions'] != null) {
               for (final e in (existingMetaJson['kexContributions'] as List)) {
                 final m = Map<String, dynamic>.from(e as Map);
                 int sByte = m['startByte'] as int? ?? 0;
                 int eByte = m['endByte'] as int? ?? 0;
                 contribById[m['kexId'] as String] = {
                   'kexId': m['kexId'],
                   'startByte': sByte,
                   'endByte': eByte,
                 };
               }
             }
             if (effectiveContrib != null) {
               for (final e in effectiveContrib) {
                 final id = e['kexId'] as String;
                 int s = e['startByte'] as int? ?? 0;
                 int ed = e['endByte'] as int? ?? 0;

                 if (contribById.containsKey(id)) {
                   contribById[id]!['startByte'] = min(contribById[id]!['startByte'] as int, s);
                   contribById[id]!['endByte'] = max(contribById[id]!['endByte'] as int, ed);
                 } else {
                   contribById[id] = {
                     'kexId': id,
                     'startByte': s,
                     'endByte': ed,
                   };
                 }
               }
             }

             final mergedContrib = contribById.values.toList();

             final metadataMap = {
               'id': key.id,
               'peerIds': combinedPeers,
               'createdAt': createdAtStr,
               'startOffset': key.startOffset,
               'lastKexId': effectiveLastKex,
               'kexContributions': mergedContrib,
               'nextAvailableByte': mergedNextAvailable,
             };

             final metadata = jsonEncode(metadataMap);
             await prefsInner.setString('$_keyPrefix$conversationId', keyData);
             await prefsInner.setString('${_keyPrefix}meta_$conversationId', metadata);

             _log.i('KeyStorage', 'saveKey: SUCCESS (merged extension)');
             return;
           }
         } catch (_) {
           // Fall back to default behavior below
         }
       }

       // Default behavior: overwrite
       await prefsInner.setString('$_keyPrefix$conversationId', keyData);
       final metadataMap = {
         'id': key.id,
         'peerIds': key.peerIds,
         'createdAt': key.createdAt.toIso8601String(),
         'startOffset': key.startOffset,
         'lastKexId': effectiveLastKex,
         'kexContributions': effectiveContrib,
         'nextAvailableByte': nextAvailable,
       };
       final metadata = jsonEncode(metadataMap);
       await prefsInner.setString('${_keyPrefix}meta_$conversationId', metadata);


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

      // Read kexContributions if present
      List<KexContribution>? kexContribs;
      final rawContrib = metadata['kexContributions'] as List?;
      if (rawContrib != null) {
        kexContribs = rawContrib
            .map((e) => KexContribution.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      final nextAvail = metadata['nextAvailableByte'] as int? ?? (metadata['startOffset'] as int? ?? 0);

       final key = SharedKey(
         id: metadata['id'] as String,
         keyData: Uint8List.fromList(keyData),
         peerIds: List<String>.from(metadata['peerIds'] as List),
         createdAt: DateTime.parse(metadata['createdAt'] as String),
         startOffset: metadata['startOffset'] as int? ?? 0,
         kexContributions: kexContribs,
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
