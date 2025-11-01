import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repartition.dart';

class RepartitionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Créer une nouvelle répartition
  Future<String> createRepartition(Repartition repartition) async {
    final docRef = await _firestore.collection('repartitions').add(repartition.toMap());
    return docRef.id;
  }

  // Récupérer les répartitions d'une tâche
  Stream<List<Repartition>> getRepartitionsForTache(String tacheId) {
    return _firestore
        .collection('repartitions')
        .where('tacheId', isEqualTo: tacheId)
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Repartition.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Mettre à jour une répartition
  Future<void> updateRepartition(Repartition repartition) async {
    await _firestore
        .collection('repartitions')
        .doc(repartition.id)
        .update(repartition.toMap());
  }

  // Supprimer une répartition
  Future<void> deleteRepartition(String repartitionId) async {
    await _firestore.collection('repartitions').doc(repartitionId).delete();
  }

  // Récupérer une répartition spécifique
  Future<Repartition?> getRepartition(String repartitionId) async {
    final doc = await _firestore.collection('repartitions').doc(repartitionId).get();
    if (!doc.exists) return null;
    return Repartition.fromMap(doc.id, doc.data()!);
  }
}
