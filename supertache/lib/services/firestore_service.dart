import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enseignant.dart';
import '../models/groupe.dart';
import '../models/tache.dart';
import '../models/cours.dart';
import '../models/enseignant_preferences.dart';
import '../models/tache_vote.dart';

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

  Future<List<Groupe>> getGroupesByTacheFuture(String tacheId) async {
    final snapshot = await _db
        .collection('groupes')
        .where('tacheId', isEqualTo: tacheId)
        .get();
    return snapshot.docs.map((doc) => Groupe.fromMap(doc.id, doc.data())).toList();
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

  Future<List<Cours>> getAllCoursFuture() async {
    final snapshot = await _db
        .collection('cours')
        .orderBy('code')
        .get();
    return snapshot.docs
        .map((doc) => Cours.fromMap(doc.id, doc.data()))
        .toList();
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

  Future<List<Enseignant>> getEnseignantsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    final enseignants = <Enseignant>[];
    for (var id in ids) {
      final doc = await _db.collection('enseignants').doc(id).get();
      
      if (doc.exists) {
        enseignants.add(Enseignant.fromMap(doc.id, doc.data()!));
      }
    }
    return enseignants;
  }

  // Préférences des enseignants
  Future<void> saveEnseignantPreferences(EnseignantPreferences preferences) async {
    await _db
        .collection('enseignant_preferences')
        .doc(preferences.enseignantId)
        .set(preferences.toMap());
  }

  Future<EnseignantPreferences?> getEnseignantPreferences(String enseignantId) async {
    final doc = await _db
        .collection('enseignant_preferences')
        .doc(enseignantId)
        .get();
    
    if (doc.exists && doc.data() != null) {
      return EnseignantPreferences.fromMap(doc.data()!);
    }
    return null;
  }

  Future<Map<String, EnseignantPreferences>> getAllEnseignantPreferences(List<String> enseignantIds) async {
    final preferences = <String, EnseignantPreferences>{};
    
    for (var id in enseignantIds) {
      final pref = await getEnseignantPreferences(id);
      if (pref != null) {
        preferences[id] = pref;
      }
    }
    
    return preferences;
  }

  // Votes des tâches
  Future<void> saveTacheVote(TacheVote vote) async {
    final docId = '${vote.tacheGenerationId}_${vote.enseignantId}';
    await _db.collection('tache_votes').doc(docId).set(vote.toMap());
  }

  Future<TacheVote?> getTacheVote(String generationId, String enseignantId) async {
    final docId = '${generationId}_$enseignantId';
    final doc = await _db.collection('tache_votes').doc(docId).get();
    
    if (doc.exists && doc.data() != null) {
      return TacheVote.fromMap(doc.data()!);
    }
    return null;
  }

  Future<List<TacheVote>> getTacheVotes(String generationId) async {
    final snapshot = await _db
        .collection('tache_votes')
        .where('tacheGenerationId', isEqualTo: generationId)
        .get();
    
    return snapshot.docs
        .map((doc) => TacheVote.fromMap(doc.data()))
        .toList();
  }

  Stream<List<TacheVote>> getTacheVotesStream(String generationId) {
    return _db
        .collection('tache_votes')
        .where('tacheGenerationId', isEqualTo: generationId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TacheVote.fromMap(doc.data()))
            .toList());
  }

  Future<List<String>> getAllEnseignantEmailsFuture() async {
    final snapshot = await _db.collection('taches').get();
    final emails = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final list = (data['enseignantEmails'] as List?)?.cast<String>() ?? const <String>[];
      emails.addAll(list.map((e) => e.toLowerCase()));
    }
    // Ajouter aussi ceux présents dans la collection enseignants
    final ensSnap = await _db.collection('enseignants').get();
    for (var doc in ensSnap.docs) {
      final data = doc.data();
      final email = (data['email'] as String?)?.toLowerCase();
      if (email != null && email.isNotEmpty) emails.add(email);
    }
    final list = emails.toList()..sort();
    return list;
  }
}
