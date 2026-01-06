import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'user_service.dart';

/// Service d'authentification avec Firebase Phone Auth.
/// Le numéro de téléphone est l'unique identifiant de l'utilisateur.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Stockage temporaire du verification ID pour la vérification OTP
  String? _verificationId;
  int? _resendToken;

  /// Stream des changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;

  /// Vérifie si un utilisateur est connecté
  bool get isSignedIn => currentUser != null;

  /// Numéro de téléphone de l'utilisateur connecté
  String? get currentPhoneNumber => currentUser?.phoneNumber;

  /// Obtient le profil de l'utilisateur actuel
  UserProfile? get currentUserProfile {
    final user = currentUser;
    if (user == null) return null;

    return UserProfile(
      uid: user.uid,
      phoneNumber: user.phoneNumber ?? '',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastSignIn: user.metadata.lastSignInTime ?? DateTime.now(),
    );
  }

  // ==================== PHONE AUTH ====================

  /// Envoie un code de vérification au numéro de téléphone
  Future<void> sendVerificationCode({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-vérification sur Android (si le SMS est détecté automatiquement)
          onAutoVerify(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          String message;
          switch (e.code) {
            case 'invalid-phone-number':
              message = 'Numéro de téléphone invalide';
              break;
            case 'too-many-requests':
              message = 'Trop de tentatives. Réessayez plus tard.';
              break;
            case 'quota-exceeded':
              message = 'Quota dépassé. Réessayez plus tard.';
              break;
            default:
              message = e.message ?? 'Erreur d\'envoi du code';
          }
          onError(message);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      onError('Erreur: $e');
    }
  }

  /// Vérifie le code OTP et connecte l'utilisateur
  Future<UserCredential> verifyOtpAndSignIn(String smsCode) async {
    if (_verificationId == null) {
      throw AuthException('Aucune vérification en cours. Demandez un nouveau code.');
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Sauvegarder l'utilisateur dans Firestore
      await _saveUserToFirestore(userCredential.user);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-verification-code':
          message = 'Code invalide. Vérifiez et réessayez.';
          break;
        case 'session-expired':
          message = 'Session expirée. Demandez un nouveau code.';
          break;
        default:
          message = e.message ?? 'Erreur de vérification';
      }
      throw AuthException(message);
    }
  }

  /// Sauvegarde l'utilisateur dans Firestore
  Future<void> _saveUserToFirestore(User? user) async {
    if (user == null || user.phoneNumber == null) return;

    try {
      final userProfile = UserProfile(
        uid: user.uid,
        phoneNumber: user.phoneNumber!,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        lastSignIn: user.metadata.lastSignInTime ?? DateTime.now(),
      );
      await _userService.saveUser(userProfile);
    } catch (e) {
      // Ne pas bloquer la connexion si l'enregistrement échoue
      print('Failed to save user to Firestore: $e');
    }
  }

  /// Connexion avec credential (utilisé pour l'auto-vérification)
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);

      // Sauvegarder l'utilisateur dans Firestore
      await _saveUserToFirestore(userCredential.user);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Erreur de connexion');
    }
  }

  // ==================== DÉCONNEXION ====================

  /// Déconnexion
  Future<void> signOut() async {
    _verificationId = null;
    _resendToken = null;
    await _auth.signOut();
  }

  // ==================== GESTION DU COMPTE ====================

  /// Supprime le compte utilisateur
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw AuthException('Aucun utilisateur connecté');

    await user.delete();
  }

  /// Réinitialise l'état de vérification
  void resetVerification() {
    _verificationId = null;
    _resendToken = null;
  }
}

/// Exception d'authentification
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
