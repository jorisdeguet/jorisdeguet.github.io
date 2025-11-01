import 'firestore_service.dart';
import '../models/groupe.dart';

class GroupeService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> createGroupe(Groupe groupe) => _firestoreService.createGroupe(groupe);
  
  Future<void> createGroupes(List<Groupe> groupes) => _firestoreService.createGroupes(groupes);
  
  Stream<List<Groupe>> getGroupesForTache(String tacheId) =>
      _firestoreService.getGroupesByTache(tacheId);
  
  Future<List<Groupe>> getGroupesForTacheFuture(String tacheId) =>
      _firestoreService.getGroupesByTacheFuture(tacheId);
  
  Future<List<Groupe>> getGroupesByIds(List<String> ids) =>
      _firestoreService.getGroupesByIds(ids);
  
  Future<void> deleteGroupe(String id) => _firestoreService.deleteGroupe(id);
  
  Future<void> deleteGroupesByTache(String tacheId) =>
      _firestoreService.deleteGroupesByTache(tacheId);
}
