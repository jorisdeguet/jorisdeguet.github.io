import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Service d'authentification simplifié (Singleton).
/// Pas de connexion téléphone - juste un pseudo et un ID unique.
class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _userIdKey = 'user_id';
  static const String _userPseudoKey = 'user_pseudo';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserProfile? _currentUser;

  /// Utilisateur actuellement connecté
  UserProfile? get currentUser => _currentUser;

  /// Vérifie si un utilisateur est connecté
  bool get isSignedIn => _currentUser != null;

  /// ID de l'utilisateur connecté
  String? get currentUserId => _currentUser?.id;

  /// Pseudo de l'utilisateur connecté
  String? get currentPseudo => _currentUser?.pseudo;

  /// Collection des utilisateurs
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Initialise le service et charge l'utilisateur depuis le stockage local
  Future<bool> initialize() async {
    debugPrint('[AuthService] initialize()');
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    final userPseudo = prefs.getString(_userPseudoKey);

    debugPrint('[AuthService] userId from prefs: $userId');
    debugPrint('[AuthService] userPseudo from prefs: $userPseudo');

    if (userId != null && userPseudo != null) {
      // Récupérer le profil depuis Firestore
      try {
        final doc = await _usersRef.doc(userId).get();
        if (doc.exists) {
          _currentUser = UserProfile.fromJson(doc.data()!);
          debugPrint('[AuthService] User loaded from Firestore: ${_currentUser?.id}');
          return true;
        } else {
          // Le document n'existe pas dans Firestore, créer un profil local
          _currentUser = UserProfile(
            id: userId,
            pseudo: userPseudo,
            createdAt: DateTime.now(),
          );
          debugPrint('[AuthService] Created local user (not in Firestore): ${_currentUser?.id}');
          return true;
        }
      } catch (e) {
        debugPrint('[AuthService] Error loading user from Firestore: $e');
        // Créer un profil local si Firestore échoue
        _currentUser = UserProfile(
          id: userId,
          pseudo: userPseudo,
          createdAt: DateTime.now(),
        );
        debugPrint('[AuthService] Created local user (Firestore error): ${_currentUser?.id}');
        return true;
      }
    }
    debugPrint('[AuthService] No user found');
    return false;
  }

  /// Crée un nouvel utilisateur avec le pseudo donné
  Future<UserProfile> createUser(String pseudo) async {
    debugPrint('[AuthService] createUser: $pseudo');

    if (pseudo.trim().isEmpty) {
      throw AuthException('Le pseudo ne peut pas être vide');
    }

    // Créer un document avec ID auto-généré
    final docRef = _usersRef.doc();
    final now = DateTime.now();

    final user = UserProfile(
      id: docRef.id,
      pseudo: pseudo.trim(),
      createdAt: now,
    );

    // Sauvegarder dans Firestore
    try {
      await docRef.set(user.toJson());
      debugPrint('[AuthService] User saved to Firestore: ${user.id}');
    } catch (e) {
      debugPrint('[AuthService] Error saving to Firestore: $e (continuing anyway)');
    }

    // Sauvegarder localement
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, user.id);
    await prefs.setString(_userPseudoKey, user.pseudo);
    debugPrint('[AuthService] User saved locally: ${user.id}');

    _currentUser = user;
    return user;
  }

  /// Met à jour le pseudo de l'utilisateur
  Future<void> updatePseudo(String newPseudo) async {
    if (_currentUser == null) {
      throw AuthException('Aucun utilisateur connecté');
    }

    if (newPseudo.trim().isEmpty) {
      throw AuthException('Le pseudo ne peut pas être vide');
    }

    try {
      await _usersRef.doc(_currentUser!.id).update({
        'pseudo': newPseudo.trim(),
      });
    } catch (e) {
      debugPrint('[AuthService] Error updating pseudo in Firestore: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPseudoKey, newPseudo.trim());

    _currentUser = _currentUser!.copyWith(pseudo: newPseudo.trim());
  }

  /// Déconnexion (efface les données locales)
  Future<void> signOut() async {
    debugPrint('[AuthService] signOut()');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userPseudoKey);
    _currentUser = null;
  }

  /// Supprime le compte utilisateur
  Future<void> deleteAccount() async {
    if (_currentUser == null) {
      throw AuthException('Aucun utilisateur connecté');
    }

    // Supprimer de Firestore
    try {
      await _usersRef.doc(_currentUser!.id).delete();
    } catch (e) {
      debugPrint('[AuthService] Error deleting from Firestore: $e');
    }

    // Déconnexion locale
    await signOut();
  }
}

/// Exception d'authentification
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

