import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../models/user_profile.dart';

/// Service d'authentification avec Firebase Auth et providers fédérés.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream des changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;

  /// Vérifie si un utilisateur est connecté
  bool get isSignedIn => currentUser != null;

  /// Obtient le profil de l'utilisateur actuel
  UserProfile? get currentUserProfile {
    final user = currentUser;
    if (user == null) return null;

    return UserProfile(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      provider: _getProviderFromUser(user),
      phoneNumber: user.phoneNumber,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastSignIn: user.metadata.lastSignInTime ?? DateTime.now(),
    );
  }

  // ==================== GOOGLE ====================

  /// Connexion avec Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw AuthException('Erreur Google Sign-In: $e');
    }
  }

  // ==================== APPLE ====================

  /// Connexion avec Apple (iOS 13+, macOS)
  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await _auth.signInWithCredential(oauthCredential);
    } catch (e) {
      throw AuthException('Erreur Apple Sign-In: $e');
    }
  }

  // ==================== FACEBOOK ====================

  /// Connexion avec Facebook
  Future<UserCredential?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      
      if (result.status != LoginStatus.success) {
        return null;
      }

      final OAuthCredential credential = 
          FacebookAuthProvider.credential(result.accessToken!.tokenString);

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw AuthException('Erreur Facebook Sign-In: $e');
    }
  }

  // ==================== MICROSOFT ====================

  /// Connexion avec Microsoft
  Future<UserCredential?> signInWithMicrosoft() async {
    try {
      final microsoftProvider = OAuthProvider('microsoft.com');
      microsoftProvider.addScope('email');
      microsoftProvider.addScope('profile');

      if (Platform.isAndroid || Platform.isIOS) {
        return await _auth.signInWithProvider(microsoftProvider);
      } else {
        return await _auth.signInWithPopup(microsoftProvider);
      }
    } catch (e) {
      throw AuthException('Erreur Microsoft Sign-In: $e');
    }
  }

  // ==================== GITHUB ====================

  /// Connexion avec GitHub
  Future<UserCredential?> signInWithGitHub() async {
    try {
      final githubProvider = OAuthProvider('github.com');
      githubProvider.addScope('read:user');
      githubProvider.addScope('user:email');

      if (Platform.isAndroid || Platform.isIOS) {
        return await _auth.signInWithProvider(githubProvider);
      } else {
        return await _auth.signInWithPopup(githubProvider);
      }
    } catch (e) {
      throw AuthException('Erreur GitHub Sign-In: $e');
    }
  }

  // ==================== DÉCONNEXION ====================

  /// Déconnexion de tous les providers
  Future<void> signOut() async {
    // Déconnexion Google si connecté
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }

    // Déconnexion Facebook si connecté
    await FacebookAuth.instance.logOut();

    // Déconnexion Firebase
    await _auth.signOut();
  }

  // ==================== UTILITAIRES ====================

  /// Détermine le provider utilisé
  AppAuthProvider _getProviderFromUser(User user) {
    if (user.providerData.isEmpty) return AppAuthProvider.email;

    final providerId = user.providerData.first.providerId;
    switch (providerId) {
      case 'google.com':
        return AppAuthProvider.google;
      case 'facebook.com':
        return AppAuthProvider.facebook;
      case 'apple.com':
        return AppAuthProvider.apple;
      case 'microsoft.com':
        return AppAuthProvider.microsoft;
      case 'github.com':
        return AppAuthProvider.github;
      default:
        return AppAuthProvider.email;
    }
  }

  /// Supprime le compte utilisateur
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw AuthException('Aucun utilisateur connecté');

    await user.delete();
  }

  /// Met à jour le profil utilisateur
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final user = currentUser;
    if (user == null) throw AuthException('Aucun utilisateur connecté');

    await user.updateDisplayName(displayName);
    await user.updatePhotoURL(photoUrl);
  }
}

/// Exception d'authentification
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
