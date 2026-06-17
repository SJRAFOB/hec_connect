import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class MessagingBadgeCard extends StatefulWidget {
  final String userId;
  const MessagingBadgeCard({super.key, required this.userId});
  @override
  State<MessagingBadgeCard> createState() => _MessagingBadgeCardState();
}

class _MessagingBadgeCardState extends State<MessagingBadgeCard> {
  Map<String, DateTime> _lastVisits = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, DateTime> visits = {};
    for (final key in prefs.getKeys().where((k) => k.startsWith('chat_visit_'))) {
      final ms = prefs.getInt(key);
      if (ms != null) {
        visits[key.replaceFirst('chat_visit_', '')] =
            DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    if (mounted) setState(() => _lastVisits = visits);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.collectionConversations)
          .where('participants', arrayContains: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        for (final doc in snapshot.data?.docs ?? []) {
          final data = doc.data() as Map<String, dynamic>;
          // Compter les CONVERSATIONS non lues (pas le total des messages)
          final lastSenderId = data['lastSenderId'] as String?;
          if (lastSenderId == widget.userId) continue; // c'est moi qui ai envoyé en dernier
          
          // Vérifier si la conversation a des messages non lus
          final rawCount = data['msgUnread_' + widget.userId];
          final msgCount = (rawCount as num?)?.toInt() ?? 0;
          if (msgCount > 0) {
            unreadCount++; // +1 conversation, pas +msgCount
            continue;
          }
          // Fallback: lastVisit
          final lastMsgTime =
              (data['lastMessageTime'] as dynamic)?.toDate() as DateTime?;
          if (lastMsgTime == null) continue;
          final lastVisit = _lastVisits[doc.id];
          if (lastVisit == null || lastMsgTime.isAfter(lastVisit)) {
            unreadCount++; // +1 conversation
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.of(context)
                .pushNamed('/messagerie')
                .then((_) => _load());
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4))],
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 32, color: Color(0xFF1C3A6B)),
                      SizedBox(height: 10),
                      Text('Messagerie',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1C3A6B))),
                    ],
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}