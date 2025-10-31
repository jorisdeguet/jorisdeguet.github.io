import 'package:firebase_auth/firebase_auth.dart';
import '../models/enseignant.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Configurer la persistance de la session
  Future<void> setPersistence(bool rememberMe) async {
    try {
      await _auth.setPersistence(
        rememberMe ? Persistence.LOCAL : Persistence.SESSION,
      );
    } catch (e) {
      // Sur Web, setPersistence peut échouer, on l'ignore
      print('Persistence setting not supported: $e');
    }
  }

  // Connexion avec email et mot de passe
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
    bool rememberMe,
  ) async {
    try {
      // Configurer la persistance avant la connexion
      await setPersistence(rememberMe);
      
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Vérifier si le document enseignant existe, sinon le créer
      if (result.user != null) {
        final existingEnseignant = await _firestoreService.getEnseignant(result.user!.uid);
        if (existingEnseignant == null) {
          // Créer un document enseignant avec des valeurs par défaut
          final enseignant = Enseignant(
            id: result.user!.uid,
            nom: result.user!.displayName?.split(' ').last ?? '',
            prenom: result.user!.displayName?.split(' ').first ?? '',
            email: email,
          );
          await _firestoreService.createEnseignant(enseignant);
        }
      }
      
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // Inscription avec email et mot de passe
  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password,
    String nom,
    String prenom,
  ) async {
    try {
      // Par défaut, on garde la session pour les nouveaux utilisateurs
      await setPersistence(true);
      
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final enseignant = Enseignant(
          id: result.user!.uid,
          nom: nom,
          prenom: prenom,
          email: email,
        );
        await _firestoreService.createEnseignant(enseignant);
      }

      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // Réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Mettre à jour le profil de l'enseignant
  Future<void> updateEnseignantProfile(String nom, String prenom) async {
    if (currentUser != null) {
      final enseignant = Enseignant(
        id: currentUser!.uid,
        nom: nom,
        prenom: prenom,
        email: currentUser!.email!,
      );
      await _firestoreService.updateEnseignant(enseignant);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
