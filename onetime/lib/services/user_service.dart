import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

/// Service pour gérer les utilisateurs de l'application dans Firestore.
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection des utilisateurs
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Récupère un utilisateur par son ID
  Future<UserProfile?> getUserById(String id) async {
    debugPrint('[UserService] getUserById: $id');
    try {
      final doc = await _usersRef.doc(id).get();
      if (!doc.exists) {
        debugPrint('[UserService] getUserById: NOT FOUND');
        return null;
      }
      debugPrint('[UserService] getUserById: FOUND');
      return UserProfile.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('[UserService] getUserById ERROR: $e');
      rethrow;
    }
  }

  /// Récupère plusieurs utilisateurs par leurs IDs
  Future<Map<String, UserProfile>> getUsersByIds(List<String> ids) async {
    debugPrint('[UserService] getUsersByIds: ${ids.length} IDs');
    final result = <String, UserProfile>{};
    
    if (ids.isEmpty) return result;
    
    try {
      // Firestore limite whereIn à 30 éléments
      const batchSize = 30;
      for (var i = 0; i < ids.length; i += batchSize) {
        final batch = ids.skip(i).take(batchSize).toList();
        final snapshot = await _usersRef.where(FieldPath.documentId, whereIn: batch).get();
        
        for (final doc in snapshot.docs) {
          result[doc.id] = UserProfile.fromJson(doc.data());
        }
      }
      
      debugPrint('[UserService] getUsersByIds: found ${result.length} users');
      return result;
    } catch (e) {
      debugPrint('[UserService] getUsersByIds ERROR: $e');
      rethrow;
    }
  }
}

