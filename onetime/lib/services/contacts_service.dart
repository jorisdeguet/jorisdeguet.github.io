import 'dart:async';
import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart' as phone_contacts;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';

/// Service de gestion des contacts.
/// 
/// Permet de:
/// - Lire les contacts du répertoire téléphone
/// - Gérer la liste des contacts de l'app
/// - Vérifier quels contacts sont utilisateurs de l'app (par numéro de téléphone)
class ContactsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String _contactsKey = 'app_contacts';

  // ==================== CONTACTS TÉLÉPHONE ====================

  /// Demande la permission d'accès aux contacts
  Future<bool> requestPermission() async {
    return await phone_contacts.FlutterContacts.requestPermission();
  }

  /// Vérifie si on a la permission d'accès aux contacts
  Future<bool> hasPermission() async {
    return await phone_contacts.FlutterContacts.requestPermission(readonly: true);
  }

  /// Récupère tous les contacts du téléphone (uniquement ceux avec numéro)
  Future<List<PhoneContact>> getPhoneContacts() async {
    if (!await hasPermission()) {
      throw ContactsException('Permission refusée');
    }

    final contacts = await phone_contacts.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );

    // Filtrer uniquement les contacts avec au moins un numéro de téléphone
    return contacts
        .where((c) => c.phones.isNotEmpty)
        .map((c) => PhoneContact(
          id: c.id,
          displayName: c.displayName,
          phones: c.phones.map((p) => p.number).toList(),
          photoUrl: c.photo != null ? 'data:image/png;base64,${base64Encode(c.photo!)}' : null,
        ))
        .toList();
  }

  /// Recherche des contacts téléphone par nom ou numéro
  Future<List<PhoneContact>> searchPhoneContacts(String query) async {
    final allContacts = await getPhoneContacts();
    final queryLower = query.toLowerCase();
    
    return allContacts.where((c) {
      return c.displayName.toLowerCase().contains(queryLower) ||
             c.phones.any((p) => p.contains(query));
    }).toList();
  }

  // ==================== CONTACTS APP ====================

  /// Charge les contacts de l'application depuis le stockage local
  Future<List<Contact>> loadAppContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString(_contactsKey);
    
    if (contactsJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(contactsJson);
    return decoded.map((json) => Contact.fromJson(json)).toList();
  }

  /// Sauvegarde les contacts de l'application
  Future<void> saveAppContacts(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_contactsKey, contactsJson);
  }

  /// Ajoute un contact à l'application
  Future<void> addContact(Contact contact) async {
    final contacts = await loadAppContacts();
    
    // Vérifier si le contact existe déjà (par numéro)
    if (contacts.any((c) => c.id == contact.id)) {
      throw ContactsException('Contact déjà ajouté');
    }
    
    contacts.add(contact);
    await saveAppContacts(contacts);
  }

  /// Supprime un contact de l'application
  Future<void> removeContact(String contactId) async {
    final contacts = await loadAppContacts();
    contacts.removeWhere((c) => c.id == contactId);
    await saveAppContacts(contacts);
  }

  /// Met à jour un contact
  Future<void> updateContact(Contact contact) async {
    final contacts = await loadAppContacts();
    final index = contacts.indexWhere((c) => c.id == contact.id);
    
    if (index == -1) {
      throw ContactsException('Contact non trouvé');
    }
    
    contacts[index] = contact;
    await saveAppContacts(contacts);
  }

  /// Trouve un contact par numéro de téléphone
  Future<Contact?> findContactByPhone(String phoneNumber) async {
    final normalized = Contact.normalizePhoneNumber(phoneNumber);
    final contacts = await loadAppContacts();

    try {
      return contacts.firstWhere((c) => c.id == normalized);
    } catch (_) {
      return null;
    }
  }

  // ==================== VÉRIFICATION FIREBASE ====================

  /// Vérifie si un numéro de téléphone correspond à un utilisateur de l'app
  Future<bool> isAppUser(String phoneNumber) async {
    final normalized = Contact.normalizePhoneNumber(phoneNumber);

    final query = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: normalized)
        .limit(1)
        .get();
    
    return query.docs.isNotEmpty;
  }

  /// Vérifie quels contacts téléphone sont des utilisateurs de l'app
  Future<List<PhoneContact>> findAppUsersInContacts(List<PhoneContact> phoneContacts) async {
    final appUsers = <PhoneContact>[];
    
    // Récupérer tous les numéros normalisés
    final phoneNumbers = <String>[];
    final phoneToContact = <String, PhoneContact>{};

    for (final contact in phoneContacts) {
      for (final phone in contact.phones) {
        final normalized = Contact.normalizePhoneNumber(phone);
        phoneNumbers.add(normalized);
        phoneToContact[normalized] = contact;
      }
    }

    // Requête par lots (Firestore limite à 30 éléments par whereIn)
    const batchSize = 30;
    for (var i = 0; i < phoneNumbers.length; i += batchSize) {
      final batch = phoneNumbers.skip(i).take(batchSize).toList();

      if (batch.isEmpty) continue;

      final query = await _firestore
          .collection('users')
          .where('phoneNumber', whereIn: batch)
          .get();

      for (final doc in query.docs) {
        final phone = doc.data()['phoneNumber'] as String?;
        if (phone != null && phoneToContact.containsKey(phone)) {
          appUsers.add(phoneToContact[phone]!);
        }
      }
    }
    
    return appUsers.toSet().toList(); // Dédupliquer
  }

  /// Importe un contact téléphone dans l'app avec vérification Firebase
  Future<Contact?> importPhoneContact(PhoneContact phoneContact) async {
    if (!phoneContact.hasPhone) {
      throw ContactsException('Le contact n\'a pas de numéro de téléphone');
    }
    
    // Vérifier si c'est un utilisateur de l'app
    final isUser = await isAppUser(phoneContact.primaryPhone!);

    final contact = phoneContact.toAppContact(isAppUser: isUser);
    if (contact == null) {
      throw ContactsException('Impossible de créer le contact');
    }

    await addContact(contact);
    return contact;
  }

  /// Enregistre l'utilisateur courant dans Firebase pour être trouvable
  Future<void> registerUser(String uid, String phoneNumber, String? displayName) async {
    final normalized = Contact.normalizePhoneNumber(phoneNumber);

    await _firestore.collection('users').doc(uid).set({
      'phoneNumber': normalized,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Met à jour le timestamp de dernière activité
  Future<void> updateLastSeen(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Met à jour la clé partagée avec un contact
  Future<void> setSharedKey(String contactId, String keyId) async {
    final contacts = await loadAppContacts();
    final index = contacts.indexWhere((c) => c.id == contactId);
    
    if (index == -1) {
      throw ContactsException('Contact non trouvé');
    }
    
    contacts[index] = contacts[index].copyWith(sharedKeyId: keyId);
    await saveAppContacts(contacts);
  }
}

/// Exception pour les erreurs de contacts
class ContactsException implements Exception {
  final String message;
  ContactsException(this.message);

  @override
  String toString() => 'ContactsException: $message';
}
