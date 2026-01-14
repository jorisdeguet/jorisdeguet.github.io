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
  static const String _usedBitsPrefix = 'used_bits_';
  final _log = AppLogger();

  /// Sauvegarde une clé partagée pour une conversation
  /// kexContributions: optional list of { 'kexId': string, 'startBit': int, 'endBit': int }
  Future<void> saveKey(String conversationId, SharedKey key, {String? lastKexId, List<Map<String, dynamic>>? kexContributions}) async {
    _log.i('KeyStorage', 'saveKey: conversationId=$conversationId, keyLength=${key.lengthInBits} bits, lastKexId=$lastKexId, contributions=${kexContributions?.length ?? 0}');

    try {
      // Prepare values to write (we will compute effective lastKexId after reading existing meta)
      final keyData = base64Encode(key.keyData);
      final usedBitmapBase64 = base64Encode(key.usedBitmap);

      // Reopen prefs and re-check to avoid redundant write after pending save
      final prefs = await SharedPreferences.getInstance();
      final existingKeyData = prefs.getString('$_keyPrefix$conversationId');
      final existingMeta = prefs.getString('${_keyPrefix}meta_$conversationId');
      final existingUsed = prefs.getString('$_usedBitsPrefix$conversationId');

      if (existingKeyData == keyData && existingUsed == usedBitmapBase64) {
        bool peersEqual = false;
        bool sameKex = false;
        bool contributionsEqual = false;
        if (existingMeta != null) {
          try {
            final Map<String, dynamic> existingMetaJson = jsonDecode(existingMeta) as Map<String, dynamic>;
            // sort peerIds to ensure consistent comparison

            final existingLastKex = existingMetaJson['lastKexId'] as String?;
            sameKex = (existingLastKex == lastKexId);

            final existingPeerIds = (existingMetaJson['peerIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final newPeerIds = List<String>.from(key.peerIds);
            existingPeerIds.sort();
            newPeerIds.sort();
            peersEqual = listEquals(existingPeerIds, newPeerIds);

            // compare contributions if provided
            final existingContrib = existingMetaJson['kexContributions'] as List?;
            if (existingContrib == null && kexContributions == null) {
              contributionsEqual = true;
            } else if (existingContrib != null && kexContributions != null) {
              // Normalize to list of maps with string keys and ints
              List<Map<String, dynamic>> a = existingContrib.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              List<Map<String, dynamic>> b = kexContributions.map((e) => Map<String, dynamic>.from(e)).toList();
              // sort by kexId
              a.sort((x, y) => (x['kexId'] as String).compareTo(y['kexId'] as String));
              b.sort((x, y) => (x['kexId'] as String).compareTo(y['kexId'] as String));
              contributionsEqual = const DeepCollectionEquality().equals(a, b);
            }
          } catch (_) {
            peersEqual = false;
            sameKex = false;
          }
        }

        if (peersEqual && sameKex && contributionsEqual) {
          _log.i('KeyStorage', 'saveKey: SKIPPED (no changes to key bytes/peers/usedBitmap and same lastKexId and contributions)');
          return;
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
        // use provided (could consider merge, but we prefer explicit provided)
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
            _log.i('KeyStorage', 'Detected key extension; merging metadata and used bitmap');

            // Merge usedBitmap: prefer existing used bits for the prefix
            Uint8List mergedUsed;
            try {
              final existingUsedStr = existingUsed;
              Uint8List existingUsedBytes;
              if (existingUsedStr != null && existingUsedStr.isNotEmpty) {
                // Try base64 first
                try {
                  existingUsedBytes = base64Decode(existingUsedStr);
                } catch (_) {
                  // Legacy format: ranges "start-end;start-end"
                  final bitmapSize = (existingBytes.length * 8 + 7) ~/ 8;
                  existingUsedBytes = Uint8List(bitmapSize);
                  final ranges = existingUsedStr.split(';');
                  for (final range in ranges) {
                    if (range.isEmpty) continue;
                    final parts = range.split('-');
                    if (parts.length != 2) continue;
                    final s = int.tryParse(parts[0]);
                    final e = int.tryParse(parts[1]);
                    if (s == null || e == null) continue;
                    for (int bit = s; bit <= e; bit++) {
                      final byteIndex = bit ~/ 8;
                      final bitOffset = bit % 8;
                      if (byteIndex < existingUsedBytes.length) {
                        existingUsedBytes[byteIndex] |= (1 << bitOffset);
                      }
                    }
                  }
                }

                final newUsedBytes = base64Decode(usedBitmapBase64);
                final mergedSize = max(existingUsedBytes.length, newUsedBytes.length);
                mergedUsed = Uint8List(mergedSize);
                // copy existing first
                mergedUsed.setRange(0, existingUsedBytes.length, existingUsedBytes);
                // OR in the rest from newUsedBytes
                for (int i = 0; i < newUsedBytes.length; i++) {
                  if (i < mergedUsed.length) mergedUsed[i] |= newUsedBytes[i];
                }
              } else {
                mergedUsed = base64Decode(usedBitmapBase64);
              }
            } catch (_) {
              mergedUsed = base64Decode(usedBitmapBase64);
            }

            // Merge peerIds (union)
            final existingMetaJson = existingMeta != null ? jsonDecode(existingMeta) as Map<String, dynamic> : null;
            final existingPeerIds = existingMetaJson != null
                ? (existingMetaJson['peerIds'] as List?)?.map((e) => e.toString()).toList() ?? []
                : [];
            final combinedPeers = {...existingPeerIds, ...key.peerIds}.toList()..sort();

            // Merge kexContributions: by kexId keep min start and max end
            final Map<String, Map<String, dynamic>> contribById = {};
            if (existingMetaJson != null && existingMetaJson['kexContributions'] != null) {
              for (final e in (existingMetaJson['kexContributions'] as List)) {
                final m = Map<String, dynamic>.from(e as Map);
                contribById[m['kexId'] as String] = {
                  'kexId': m['kexId'],
                  'startBit': m['startBit'],
                  'endBit': m['endBit'],
                };
              }
            }
            if (effectiveContrib != null) {
              for (final e in effectiveContrib) {
                final id = e['kexId'] as String;
                if (contribById.containsKey(id)) {
                  contribById[id]!['startBit'] = min(contribById[id]!['startBit'] as int, e['startBit'] as int);
                  contribById[id]!['endBit'] = max(contribById[id]!['endBit'] as int, e['endBit'] as int);
                } else {
                  contribById[id] = {
                    'kexId': id,
                    'startBit': e['startBit'],
                    'endBit': e['endBit'],
                  };
                }
              }
            }

            final mergedContrib = contribById.values.map((v) => v).toList();

            // Preserve createdAt from existing meta when extending
            String createdAtStr = key.createdAt.toIso8601String();
            if (existingMetaJson != null && existingMetaJson['createdAt'] != null) {
              createdAtStr = existingMetaJson['createdAt'] as String;
            }

            final metadataMap = {
              'id': key.id,
              'peerIds': combinedPeers,
              'createdAt': createdAtStr,
              'startOffset': key.startOffset,
              'lastKexId': effectiveLastKex,
              'kexContributions': mergedContrib,
            };

            final metadata = jsonEncode(metadataMap);
            await prefsInner.setString('$_keyPrefix$conversationId', keyData);
            await prefsInner.setString('${_keyPrefix}meta_$conversationId', metadata);
            await prefsInner.setString('$_usedBitsPrefix$conversationId', base64Encode(mergedUsed));


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
      };
      final metadata = jsonEncode(metadataMap);
      await prefsInner.setString('${_keyPrefix}meta_$conversationId', metadata);
      await prefsInner.setString('$_usedBitsPrefix$conversationId', usedBitmapBase64);


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

      // Read kexContributions if present
      List<KexContribution>? kexContribs;
      final rawContrib = metadata['kexContributions'] as List?;
      if (rawContrib != null) {
        kexContribs = rawContrib
            .map((e) => KexContribution.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      final key = SharedKey(
        id: metadata['id'] as String,
        keyData: Uint8List.fromList(keyData),
        peerIds: List<String>.from(metadata['peerIds'] as List),
        createdAt: DateTime.parse(metadata['createdAt'] as String),
        usedBitmap: usedBitmap,
        startOffset: metadata['startOffset'] as int? ?? 0,
        kexContributions: kexContribs,
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
