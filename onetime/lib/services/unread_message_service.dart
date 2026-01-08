import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour tracker les messages non lus par conversation
class UnreadMessageService {
  static const String _prefix = 'unread_msgs_';

  /// Incrémente le compteur de messages non lus
  Future<void> incrementUnread(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$conversationId';
      final current = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, current + 1);
      debugPrint('[UnreadMsg] Incremented unread for $conversationId: ${current + 1}');
    } catch (e) {
      debugPrint('[UnreadMsg] Error incrementing unread: $e');
    }
  }

  /// Récupère le nombre de messages non lus
  Future<int> getUnreadCount(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$conversationId';
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      debugPrint('[UnreadMsg] Error getting unread count: $e');
      return 0;
    }
  }

  /// Marque tous les messages comme lus (remet à zéro)
  Future<void> markAllAsRead(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$conversationId';
      await prefs.setInt(key, 0);
      debugPrint('[UnreadMsg] Marked all as read for $conversationId');
    } catch (e) {
      debugPrint('[UnreadMsg] Error marking all as read: $e');
    }
  }

  /// Supprime le compteur pour une conversation
  Future<void> deleteUnreadCount(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$conversationId';
      await prefs.remove(key);
    } catch (e) {
      debugPrint('[UnreadMsg] Error deleting unread count: $e');
    }
  }

  /// Supprime tous les compteurs
  Future<void> deleteAllUnreadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_prefix)) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('[UnreadMsg] All unread counts deleted');
    } catch (e) {
      debugPrint('[UnreadMsg] Error deleting all unread counts: $e');
    }
  }
}
