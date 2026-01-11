import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/shared_key.dart';
import 'key_storage_service.dart';
import 'message_storage_service.dart';
import 'conversation_pseudo_service.dart';

/// Service pour exporter et importer des conversations vers un autre appareil.
class ConversationExportService {
  final KeyStorageService _keyStorage = KeyStorageService();
  final MessageStorageService _messageStorage = MessageStorageService();
  final ConversationPseudoService _pseudoService = ConversationPseudoService();

  /// Exporte une conversation unique avec toutes ses données
  Future<ConversationExportData?> exportConversation(String conversationId) async {
    try {
      debugPrint('[ExportService] Exporting conversation $conversationId');

      // Charger la clé partagée
      final sharedKey = await _keyStorage.getKey(conversationId);
      if (sharedKey == null) {
        debugPrint('[ExportService] No shared key found for conversation');
        return null;
      }

      // Charger les messages locaux
      final messages = await _messageStorage.getConversationMessages(conversationId);
      debugPrint('[ExportService] Found ${messages.length} local messages');

      // Charger les pseudos
      final pseudos = await _pseudoService.getPseudos(conversationId);
      debugPrint('[ExportService] Found ${pseudos.length} pseudos');

      // Calculate used bits by counting set bits in the bitmap
      int usedBits = 0;
      for (int i = sharedKey.startOffset; i < sharedKey.lengthInBits; i++) {
        if (sharedKey.isBitUsed(i)) {
          usedBits++;
        }
      }

      return ConversationExportData(
        conversationId: conversationId,
        peerIds: sharedKey.peerIds,
        sharedKeyData: sharedKey.keyData,
        usedKeyBits: usedBits,
        totalKeyBits: sharedKey.lengthInBits,
        localMessages: messages.map((m) => m.toJson()).toList(),
        pseudos: pseudos,
        exportedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[ExportService] Error exporting conversation: $e');
      return null;
    }
  }

  /// Exporte toutes les conversations de l'utilisateur
  Future<List<ConversationExportData>> exportAllConversations() async {
    final exports = <ConversationExportData>[];
    
    try {
      // Obtenir la liste de toutes les conversations avec des clés
      final conversationIds = await _keyStorage.listConversationsWithKeys();
      debugPrint('[ExportService] Exporting ${conversationIds.length} conversations');

      for (final convId in conversationIds) {
        final exportData = await exportConversation(convId);
        if (exportData != null) {
          exports.add(exportData);
        }
      }

      debugPrint('[ExportService] Successfully exported ${exports.length} conversations');
      return exports;
    } catch (e) {
      debugPrint('[ExportService] Error exporting all conversations: $e');
      return exports;
    }
  }

  /// Importe une conversation sur ce nouvel appareil
  Future<bool> importConversation(ConversationExportData exportData) async {
    try {
      debugPrint('[ExportService] Importing conversation ${exportData.conversationId}');

      // Vérifier si la conversation existe déjà
      final existing = await _keyStorage.getKey(exportData.conversationId);
      if (existing != null) {
        debugPrint('[ExportService] Conversation already exists, skipping import');
        return false;
      }

      // Créer la clé partagée
      final sharedKey = SharedKey(
        id: exportData.conversationId,
        keyData: exportData.sharedKeyData,
        peerIds: exportData.peerIds,
      );

      // Marquer les bits utilisés
      if (exportData.usedKeyBits > 0) {
        sharedKey.markBitsAsUsed(0, exportData.usedKeyBits);
      }

      // Sauvegarder la clé
      await _keyStorage.saveKey(exportData.conversationId, sharedKey);
      debugPrint('[ExportService] Shared key imported');

      // Importer les messages locaux
      for (final msgJson in exportData.localMessages) {
        final message = DecryptedMessageData.fromJson(msgJson);
        await _messageStorage.saveDecryptedMessage(
          conversationId: exportData.conversationId,
          message: message,
        );
      }
      debugPrint('[ExportService] ${exportData.localMessages.length} messages imported');

      // Importer les pseudos
      for (final entry in exportData.pseudos.entries) {
        await _pseudoService.setPseudo(
          exportData.conversationId,
          entry.key,
          entry.value,
        );
      }
      debugPrint('[ExportService] ${exportData.pseudos.length} pseudos imported');

      debugPrint('[ExportService] Conversation imported successfully');
      return true;
    } catch (e) {
      debugPrint('[ExportService] Error importing conversation: $e');
      return false;
    }
  }

  /// Importe plusieurs conversations
  Future<int> importConversations(List<ConversationExportData> exports) async {
    int successCount = 0;

    for (final exportData in exports) {
      final success = await importConversation(exportData);
      if (success) successCount++;
    }

    debugPrint('[ExportService] Imported $successCount/${exports.length} conversations');
    return successCount;
  }

  /// Encode les données d'export en JSON
  String encodeExportData(ConversationExportData data) {
    return jsonEncode(data.toJson());
  }

  /// Encode plusieurs exports en JSON
  String encodeExportDataList(List<ConversationExportData> dataList) {
    return jsonEncode(dataList.map((d) => d.toJson()).toList());
  }

  /// Décode les données d'export depuis JSON
  ConversationExportData? decodeExportData(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ConversationExportData.fromJson(json);
    } catch (e) {
      debugPrint('[ExportService] Error decoding export data: $e');
      return null;
    }
  }

  /// Décode plusieurs exports depuis JSON
  List<ConversationExportData> decodeExportDataList(String jsonStr) {
    try {
      final jsonList = jsonDecode(jsonStr) as List;
      return jsonList
          .map((json) => ConversationExportData.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ExportService] Error decoding export data list: $e');
      return [];
    }
  }
}

/// Données d'export d'une conversation
class ConversationExportData {
  final String conversationId;
  final List<String> peerIds;
  final Uint8List sharedKeyData;
  final int usedKeyBits;
  final int totalKeyBits;
  final List<Map<String, dynamic>> localMessages;
  final Map<String, String> pseudos;
  final DateTime exportedAt;

  ConversationExportData({
    required this.conversationId,
    required this.peerIds,
    required this.sharedKeyData,
    required this.usedKeyBits,
    required this.totalKeyBits,
    required this.localMessages,
    required this.pseudos,
    required this.exportedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'peerIds': peerIds,
      'sharedKeyData': base64Encode(sharedKeyData),
      'usedKeyBits': usedKeyBits,
      'totalKeyBits': totalKeyBits,
      'localMessages': localMessages,
      'pseudos': pseudos,
      'exportedAt': exportedAt.toIso8601String(),
      'version': 1, // Version du format d'export
    };
  }

  factory ConversationExportData.fromJson(Map<String, dynamic> json) {
    return ConversationExportData(
      conversationId: json['conversationId'] as String,
      peerIds: List<String>.from(json['peerIds'] as List),
      sharedKeyData: base64Decode(json['sharedKeyData'] as String),
      usedKeyBits: json['usedKeyBits'] as int,
      totalKeyBits: json['totalKeyBits'] as int,
      localMessages: List<Map<String, dynamic>>.from(
        (json['localMessages'] as List).map((m) => m as Map<String, dynamic>),
      ),
      pseudos: Map<String, String>.from(json['pseudos'] as Map),
      exportedAt: DateTime.parse(json['exportedAt'] as String),
    );
  }

  /// Taille des données en bytes
  int get dataSizeBytes {
    return sharedKeyData.length +
        localMessages.fold<int>(0, (sum, msg) {
          final content = msg['binaryContent'] as String?;
          return sum + (content != null ? base64Decode(content).length : 0);
        });
  }
}
