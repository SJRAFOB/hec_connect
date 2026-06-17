// lib/services/presence_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> setOnline(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> setOffline(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
