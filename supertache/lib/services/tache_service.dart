import 'firestore_service.dart';
import '../models/tache.dart';

class TacheService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> createTache(Tache tache) => _firestoreService.createTache(tache);
  
  Future<void> updateTache(Tache tache) => _firestoreService.updateTache(tache);
  
  Stream<List<Tache>> getAllTaches() => _firestoreService.getAllTaches();
  
  Stream<List<Tache>> getTachesForEnseignant(String enseignantId) =>
      _firestoreService.getTachesForEnseignant(enseignantId);
  
  Future<Tache?> getTache(String id) => _firestoreService.getTache(id);
  
  Future<void> deleteTache(String id) => _firestoreService.deleteTache(id);
}
