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
/// - Vérifier quels contacts sont utilisateurs de l'app
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

  /// Récupère tous les contacts du téléphone
  Future<List<PhoneContact>> getPhoneContacts() async {
    if (!await hasPermission()) {
      throw ContactsException('Permission refusée');
    }

    final contacts = await phone_contacts.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );

    return contacts.map((c) => PhoneContact(
      id: c.id,
      displayName: c.displayName,
      emails: c.emails.map((e) => e.address).toList(),
      phones: c.phones.map((p) => p.number).toList(),
      photoUrl: c.photo != null ? 'data:image/png;base64,${base64Encode(c.photo!)}' : null,
    )).toList();
  }

  /// Recherche des contacts téléphone par nom
  Future<List<PhoneContact>> searchPhoneContacts(String query) async {
    final allContacts = await getPhoneContacts();
    final queryLower = query.toLowerCase();
    
    return allContacts.where((c) {
      return c.displayName.toLowerCase().contains(queryLower) ||
             c.emails.any((e) => e.toLowerCase().contains(queryLower)) ||
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
    
    // Vérifier si le contact existe déjà
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

  // ==================== VÉRIFICATION FIREBASE ====================

  /// Vérifie si un email correspond à un utilisateur de l'app
  Future<String?> findUserByEmail(String email) async {
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }

  /// Vérifie quels contacts téléphone sont des utilisateurs de l'app
  Future<List<PhoneContact>> findAppUsersInContacts(List<PhoneContact> phoneContacts) async {
    final appUsers = <PhoneContact>[];
    
    for (final contact in phoneContacts) {
      for (final email in contact.emails) {
        final uid = await findUserByEmail(email);
        if (uid != null) {
          appUsers.add(contact);
          break;
        }
      }
    }
    
    return appUsers;
  }

  /// Importe un contact téléphone dans l'app avec vérification Firebase
  Future<Contact> importPhoneContact(PhoneContact phoneContact) async {
    String? firebaseUid;
    bool isAppUser = false;
    
    // Chercher si c'est un utilisateur de l'app
    for (final email in phoneContact.emails) {
      firebaseUid = await findUserByEmail(email);
      if (firebaseUid != null) {
        isAppUser = true;
        break;
      }
    }
    
    final contact = phoneContact.toAppContact(
      firebaseUid: firebaseUid,
      isAppUser: isAppUser,
    );
    
    await addContact(contact);
    return contact;
  }

  /// Enregistre l'utilisateur courant dans Firebase pour être trouvable
  Future<void> registerUser(String uid, String email, String? displayName) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email.toLowerCase(),
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
