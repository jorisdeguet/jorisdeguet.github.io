import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enseignant.dart';
import '../models/groupe.dart';
import '../models/tache.dart';
import '../models/cours.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sessions/Tâches (maintenant fusionnées)
  Future<void> createTache(Tache tache) async {
    // Résoudre les emails en IDs d'enseignants
    final enseignantIds = await _resolveEmailsToIds(tache.enseignantEmails);
    final tacheWithIds = tache.copyWith(enseignantIds: enseignantIds);
    await _db.collection('taches').doc(tache.id).set(tacheWithIds.toMap());
  }

  Future<void> updateTache(Tache tache) async {
    final enseignantIds = await _resolveEmailsToIds(tache.enseignantEmails);
    final tacheWithIds = tache.copyWith(enseignantIds: enseignantIds);
    await _db.collection('taches').doc(tache.id).update(tacheWithIds.toMap());
  }

  Stream<List<Tache>> getAllTaches() {
    return _db
        .collection('taches')
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Tache.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<Tache>> getTachesForEnseignant(String enseignantId) {
    return _db
        .collection('taches')
        .where('enseignantIds', arrayContains: enseignantId)
        .snapshots()
        .map((snapshot) {
      final taches = snapshot.docs
          .map((doc) => Tache.fromMap(doc.id, doc.data()))
          .toList();
      // Trier en mémoire au lieu d'utiliser orderBy avec arrayContains
      taches.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
      return taches;
    });
  }

  Future<Tache?> getTache(String id) async {
    final doc = await _db.collection('taches').doc(id).get();
    if (doc.exists) {
      return Tache.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  Future<void> deleteTache(String id) async {
    // Supprimer aussi les groupes associés
    await deleteGroupesByTache(id);
    await _db.collection('taches').doc(id).delete();
  }

  // Enseignants
  Future<void> createEnseignant(Enseignant enseignant) async {
    await _db.collection('enseignants').doc(enseignant.id).set(enseignant.toMap());
  }

  Future<void> updateEnseignant(Enseignant enseignant) async {
    await _db.collection('enseignants').doc(enseignant.id).update(enseignant.toMap());
  }

  Stream<List<Enseignant>> getEnseignants() {
    return _db.collection('enseignants').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Enseignant.fromMap(doc.id, doc.data())).toList());
  }

  Future<Enseignant?> getEnseignant(String id) async {
    final doc = await _db.collection('enseignants').doc(id).get();
    if (doc.exists) {
      return Enseignant.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  Stream<Enseignant?> getEnseignantStream(String id) {
    return _db.collection('enseignants').doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return Enseignant.fromMap(doc.id, doc.data()!);
      }
      return null;
    });
  }

  // Groupes
  Future<void> createGroupe(Groupe groupe) async {
    await _db.collection('groupes').doc(groupe.id).set(groupe.toMap());
  }

  Future<void> createGroupes(List<Groupe> groupes) async {
    final batch = _db.batch();
    for (var groupe in groupes) {
      batch.set(_db.collection('groupes').doc(groupe.id), groupe.toMap());
    }
    await batch.commit();
  }

  Stream<List<Groupe>> getGroupesByTache(String tacheId) {
    return _db
        .collection('groupes')
        .where('tacheId', isEqualTo: tacheId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Groupe.fromMap(doc.id, doc.data())).toList());
  }

  Future<List<Groupe>> getGroupesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final docs = await Future.wait(
      ids.map((id) => _db.collection('groupes').doc(id).get()),
    );
    return docs
        .where((doc) => doc.exists)
        .map((doc) => Groupe.fromMap(doc.id, doc.data()!))
        .toList();
  }

  Future<void> deleteGroupe(String id) async {
    await _db.collection('groupes').doc(id).delete();
  }

  Future<void> deleteGroupesByTache(String tacheId) async {
    final snapshot = await _db.collection('groupes')
        .where('tacheId', isEqualTo: tacheId)
        .get();
    
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Cours
  Future<void> createCours(Cours cours) async {
    await _db.collection('cours').doc(cours.id).set(cours.toMap());
  }

  Future<void> createCoursList(List<Cours> coursList) async {
    final batch = _db.batch();
    for (var cours in coursList) {
      batch.set(_db.collection('cours').doc(cours.id), cours.toMap());
    }
    await batch.commit();
  }

  Future<void> updateCours(Cours cours) async {
    await _db.collection('cours').doc(cours.id).update(cours.toMap());
  }

  Stream<List<Cours>> getAllCours() {
    return _db
        .collection('cours')
        .orderBy('code')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Cours.fromMap(doc.id, doc.data())).toList());
  }

  Future<Cours?> getCours(String id) async {
    final doc = await _db.collection('cours').doc(id).get();
    if (doc.exists) {
      return Cours.fromMap(doc.id, doc.data()!);
    }
    return null;
  }

  Future<void> deleteCours(String id) async {
    await _db.collection('cours').doc(id).delete();
  }

  Future<void> deleteAllCours() async {
    final snapshot = await _db.collection('cours').get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Résoudre les emails en IDs d'enseignants
  Future<List<String>> _resolveEmailsToIds(List<String> emails) async {
    final ids = <String>[];
    for (var email in emails) {
      final snapshot = await _db
          .collection('enseignants')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        ids.add(snapshot.docs.first.id);
      }
    }
    return ids;
  }

  // Obtenir les enseignants par emails
  Future<List<Enseignant>> getEnseignantsByEmails(List<String> emails) async {
    if (emails.isEmpty) return [];
    
    final enseignants = <Enseignant>[];
    for (var email in emails) {
      final snapshot = await _db
          .collection('enseignants')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        enseignants.add(
          Enseignant.fromMap(snapshot.docs.first.id, snapshot.docs.first.data())
        );
      }
    }
    return enseignants;
  }
}
