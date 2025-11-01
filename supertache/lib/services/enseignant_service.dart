import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import '../models/enseignant.dart';

class EnseignantService {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createEnseignant(Enseignant enseignant) =>
      _firestoreService.createEnseignant(enseignant);
  
  Future<void> updateEnseignant(Enseignant enseignant) =>
      _firestoreService.updateEnseignant(enseignant);
  
  Stream<List<Enseignant>> getEnseignants() => _firestoreService.getEnseignants();
  
  Future<Enseignant?> getEnseignant(String id) => _firestoreService.getEnseignant(id);
  
  Stream<Enseignant?> getEnseignantStream(String id) =>
      _firestoreService.getEnseignantStream(id);
  
  Future<Enseignant?> getEnseignantByEmail(String email) async {
    final snapshot = await _db
        .collection('enseignants')
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return Enseignant.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
    }
    return null;
  }
  
  Future<List<Enseignant>> getEnseignantsByEmails(List<String> emails) =>
      _firestoreService.getEnseignantsByEmails(emails);

  Future<List<Enseignant>> getEnseignantsByIds(List<String> ids) =>
      _firestoreService.getEnseignantsByIds(ids);
}
