import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

/// Service pour gérer les utilisateurs de l'application dans Firestore.
/// Permet de rechercher des utilisateurs par numéro de téléphone.
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection des utilisateurs
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Enregistre ou met à jour un utilisateur dans Firestore
  Future<void> saveUser(UserProfile user) async {
    debugPrint('[UserService] saveUser: ${user.phoneNumber}');
    try {
      await _usersRef.doc(user.phoneNumber).set(user.toJson(), SetOptions(merge: true));
      debugPrint('[UserService] saveUser SUCCESS: ${user.phoneNumber}');
    } catch (e) {
      debugPrint('[UserService] saveUser ERROR: $e');
      rethrow;
    }
  }

  /// Récupère un utilisateur par son numéro de téléphone
  Future<UserProfile?> getUserByPhone(String phoneNumber) async {
    debugPrint('[UserService] getUserByPhone: $phoneNumber');
    try {
      final doc = await _usersRef.doc(phoneNumber).get();
      if (!doc.exists) {
        debugPrint('[UserService] getUserByPhone: NOT FOUND');
        return null;
      }
      debugPrint('[UserService] getUserByPhone: FOUND');
      return UserProfile.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('[UserService] getUserByPhone ERROR: $e');
      rethrow;
    }
  }

  /// Recherche des utilisateurs par numéro de téléphone (partiel)
  /// Retourne les utilisateurs dont le numéro contient les chiffres recherchés
  Future<List<UserProfile>> searchUsersByPhone(String phoneDigits, {int limit = 10}) async {
    debugPrint('[UserService] searchUsersByPhone: $phoneDigits');
    if (phoneDigits.length < 5) return [];

    // Extraire uniquement les chiffres
    final digits = phoneDigits.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 5) return [];

    try {
      // Firestore ne supporte pas la recherche "contains", donc on récupère tous les utilisateurs
      // et on filtre côté client. Pour une app de production, utiliser Algolia ou une Cloud Function.
      final snapshot = await _usersRef.limit(100).get();
      debugPrint('[UserService] searchUsersByPhone: fetched ${snapshot.docs.length} users');

      final users = snapshot.docs
          .map((doc) => UserProfile.fromJson(doc.data()))
          .where((user) {
            final userDigits = user.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
            return userDigits.contains(digits);
          })
          .take(limit)
          .toList();

      debugPrint('[UserService] searchUsersByPhone: found ${users.length} matching users');
      return users;
    } catch (e) {
      debugPrint('[UserService] searchUsersByPhone ERROR: $e');
      rethrow;
    }
  }

  /// Récupère tous les utilisateurs (pour suggestions)
  Future<List<UserProfile>> getAllUsers({int limit = 50}) async {
    debugPrint('[UserService] getAllUsers');
    try {
      final snapshot = await _usersRef.limit(limit).get();
      debugPrint('[UserService] getAllUsers: fetched ${snapshot.docs.length} users');
      return snapshot.docs
          .map((doc) => UserProfile.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[UserService] getAllUsers ERROR: $e');
      rethrow;
    }
  }

  /// Vérifie si un numéro de téléphone est un utilisateur de l'app
  Future<bool> isAppUser(String phoneNumber) async {
    debugPrint('[UserService] isAppUser: $phoneNumber');
    try {
      final doc = await _usersRef.doc(phoneNumber).get();
      debugPrint('[UserService] isAppUser: ${doc.exists}');
      return doc.exists;
    } catch (e) {
      debugPrint('[UserService] isAppUser ERROR: $e');
      rethrow;
    }
  }

  /// Stream des utilisateurs (pour mise à jour en temps réel)
  Stream<List<UserProfile>> watchUsers({int limit = 50}) {
    debugPrint('[UserService] watchUsers');
    return _usersRef.limit(limit).snapshots().map((snapshot) {
      debugPrint('[UserService] watchUsers: received ${snapshot.docs.length} users');
      return snapshot.docs.map((doc) => UserProfile.fromJson(doc.data())).toList();
    });
  }
}

