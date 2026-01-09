import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service d'authentification utilisant Firebase Anonymous Auth.
class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// ID de l'utilisateur connecté
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Vérifie si un utilisateur est connecté
  bool get isSignedIn => FirebaseAuth.instance.currentUser != null;

  /// Initialise le service et connecte l'utilisateur anonymement si nécessaire
  Future<bool> initialize() async {
    debugPrint('[AuthService] initialize()');
    
    // Écouter les changements d'état (optionnel pour debug)
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        debugPrint('[AuthService] User is currently signed out!');
      } else {
        debugPrint('[AuthService] User is signed in: ${user.uid}');
      }
    });

    if (!isSignedIn) {
      debugPrint('[AuthService] No user signed in, attempting anonymous sign-in...');
      await signInAnonymously();
    } else {
      debugPrint('[AuthService] Already signed in with ID: $currentUserId');
    }
    
    return isSignedIn;
  }

  /// Connecte l'utilisateur de manière anonyme
  Future<String?> signInAnonymously() async {
    debugPrint('[AuthService] signInAnonymously');
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      final user = userCredential.user;
      debugPrint('[AuthService] Signed in anonymously with UID: ${user?.uid}');
      return user?.uid;
    } catch (e) {
      debugPrint('[AuthService] signInAnonymously ERROR: $e');
      throw AuthException('Failed to sign in anonymously: $e');
    }
  }

  /// Alias pour créer un utilisateur (compatibilité) - en fait c'est un sign in
  Future<String> createUser() async {
    // Si déjà connecté, on garde l'utilisateur actuel
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      debugPrint('[AuthService] createUser: Already signed in as ${currentUser.uid}');
      return currentUser.uid;
    }

    final uid = await signInAnonymously();
    if (uid == null) throw AuthException('Failed to retrieve UID after sign in');
    return uid;
  }

  /// Déconnexion
  Future<void> signOut() async {
    debugPrint('[AuthService] signOut()');
    await FirebaseAuth.instance.signOut();
  }

  /// Supprime le compte utilisateur
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AuthException('Aucun utilisateur connecté');
    }

    try {
      await user.delete();
      debugPrint('[AuthService] Account deleted');
    } catch (e) {
      debugPrint('[AuthService] deleteAccount ERROR: $e');
      throw AuthException('Failed to delete account: $e');
    }
  }
}

/// Exception d'authentification
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

