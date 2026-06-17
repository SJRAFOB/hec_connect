import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/announcement_model.dart';
import '../models/schedule_model.dart';
import '../models/message_model.dart';
import '../utils/constants.dart';

class DatabaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== ANNONCES =====

  Stream<List<Announcement>> announcementsStream() {
    return _firestore
        .collection(AppConstants.collectionAnnouncements)
        .orderBy('publishedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Announcement.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<bool> createAnnouncement(Announcement announcement) async {
    try {
      await _firestore
          .collection(AppConstants.collectionAnnouncements)
          .add(announcement.toMap());
      return true;
    } catch (e) {
      debugPrint('Erreur création annonce: $e');
      return false;
    }
  }

  Future<bool> deleteAnnouncement(String id) async {
    try {
      await _firestore
          .collection(AppConstants.collectionAnnouncements)
          .doc(id)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Erreur suppression annonce: $e');
      return false;
    }
  }

  // ===== EMPLOIS DU TEMPS =====

  Stream<Schedule?> scheduleStream({
    required String filiere,
    required String niveau,
  }) {
    return _firestore
        .collection(AppConstants.collectionSchedules)
        .where('filiere', isEqualTo: filiere)
        .where('niveau', isEqualTo: niveau)
        .orderBy('weekStart', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return Schedule.fromMap(doc.data(), doc.id);
    });
  }

  Future<bool> saveSchedule(Schedule schedule) async {
    try {
      if (schedule.id.isEmpty) {
        await _firestore
            .collection(AppConstants.collectionSchedules)
            .add(schedule.toMap());
      } else {
        await _firestore
            .collection(AppConstants.collectionSchedules)
            .doc(schedule.id)
            .set(schedule.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('Erreur sauvegarde emploi du temps: $e');
      return false;
    }
  }

  // ===== MESSAGES =====

  String conversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<List<Conversation>> conversationsStream(String userId) {
    return _firestore
        .collection(AppConstants.collectionConversations)
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Conversation.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Message>> messagesStream(String conversationId) {
    return _firestore
        .collection(AppConstants.collectionConversations)
        .doc(conversationId)
        .collection(AppConstants.collectionMessages)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Message.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<bool> sendMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String receiverName,
    required String content,
  }) async {
    try {
      final convId = conversationId(senderId, receiverId);
      final convRef = _firestore
          .collection(AppConstants.collectionConversations)
          .doc(convId);

      final now = DateTime.now();
      final message = Message(
        id: '',
        senderId: senderId,
        senderName: senderName,
        content: content,
        sentAt: now,
      );

      await _firestore.runTransaction((transaction) async {
        final convDoc = await transaction.get(convRef);

        if (!convDoc.exists) {
          transaction.set(convRef, {
            'participants': [senderId, receiverId],
            'participantNames': {
              senderId: senderName,
              receiverId: receiverName,
            },
            'lastMessage': content,
            'lastSenderId': senderId,
            'lastMessageAt': Timestamp.fromDate(now),
            'unreadCount': {receiverId: 1},
          });
        } else {
          final data = convDoc.data()!;
          final unread = Map<String, int>.from(data['unreadCount'] ?? {});
          unread[receiverId] = (unread[receiverId] ?? 0) + 1;
          transaction.update(convRef, {
            'lastMessage': content,
            'lastSenderId': senderId,
            'lastMessageAt': Timestamp.fromDate(now),
            'unreadCount': unread,
          });
        }
      });

      await convRef
          .collection(AppConstants.collectionMessages)
          .add(message.toMap());

      return true;
    } catch (e) {
      debugPrint('Erreur envoi message: $e');
      return false;
    }
  }

  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.collectionConversations)
          .doc(conversationId)
          .update({'unreadCount.$userId': 0});
    } catch (e) {
      debugPrint('Erreur mark as read: $e');
    }
  }
}