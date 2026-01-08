import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service d'authentification simplifié (Singleton).
/// L'ID utilisateur est un UUID stocké localement uniquement.
class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _userIdKey = 'user_id';

  String? _currentUserId;

  /// ID de l'utilisateur connecté
  String? get currentUserId => _currentUserId;

  /// Vérifie si un utilisateur est connecté
  bool get isSignedIn => _currentUserId != null;

  /// Initialise le service et charge l'ID depuis le stockage local
  Future<bool> initialize() async {
    debugPrint('[AuthService] initialize()');
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString(_userIdKey);

    debugPrint('[AuthService] userId from prefs: $_currentUserId');
    return _currentUserId != null;
  }

  /// Crée un nouvel utilisateur avec un ID aléatoire
  Future<String> createUser() async {
    debugPrint('[AuthService] createUser');

    // Générer un ID unique
    const uuid = Uuid();
    final userId = uuid.v4();

    // Sauvegarder localement
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    debugPrint('[AuthService] User saved locally: $userId');

    _currentUserId = userId;
    return userId;
  }

  /// Déconnexion (efface les données locales)
  Future<void> signOut() async {
    debugPrint('[AuthService] signOut()');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    _currentUserId = null;
  }

  /// Supprime le compte utilisateur
  Future<void> deleteAccount() async {
    if (_currentUserId == null) {
      throw AuthException('Aucun utilisateur connecté');
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

