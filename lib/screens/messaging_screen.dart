import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'chat_screen.dart';
import 'new_conversation_screen.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});
  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  Map<String, DateTime> _lastVisits = {};

  @override
  void initState() {
    super.initState();
    _loadLastVisits();
  }

  Future<void> _loadLastVisits() async {
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

  Future<void> _markRead(String convId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt('chat_visit_$convId', now.millisecondsSinceEpoch);
    if (mounted) setState(() => _lastVisits[convId] = now);
  }

  bool _hasUnread(Map<String, dynamic> data, String convId, String userId) {
    final lastSenderId = data['lastSenderId'] as String?;
    if (lastSenderId == userId) return false;
    final rawCount = data['msgUnread_$userId'];
    final msgCount = (rawCount as num?)?.toInt() ?? 0;
    if (msgCount > 0) return true;
    final lastMsgTime = (data['lastMessageTime'] as dynamic)?.toDate() as DateTime?;
    if (lastMsgTime == null) return false;
    final lastVisit = _lastVisits[convId];
    return lastVisit == null || lastMsgTime.isAfter(lastVisit);
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes < 1 ? 1 : diff.inMinutes} min';
    if (diff.inHours < 24) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Messagerie',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1C3A6B),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NewConversationScreen())),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.collectionConversations)
            .where('participants', arrayContains: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1C3A6B)));
          }

          var docs = snapshot.data?.docs ?? [];
          docs = List.from(docs)..sort((a, b) {
            final aT = ((a.data() as Map)['lastMessageTime'] as dynamic)
                    ?.toDate() ?? DateTime(0);
            final bT = ((b.data() as Map)['lastMessageTime'] as dynamic)
                    ?.toDate() ?? DateTime(0);
            return bT.compareTo(aT);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Aucune conversation',
                      style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Appuyez sur ✏️ pour démarrer',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
            );
          }

          // Compter les conversations non lues
          int totalUnread = 0;
          for (final doc in docs) {
            if (_hasUnread(doc.data() as Map<String, dynamic>, doc.id, user.uid)) {
              totalUnread++;
            }
          }

          return Column(
            children: [
              if (totalUnread > 0)
                Container(
                  color: const Color(0xFF1C3A6B).withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_unread_chat_alt,
                          size: 16, color: Color(0xFF1C3A6B)),
                      const SizedBox(width: 8),
                      Text(
                        '$totalUnread conversation${totalUnread > 1 ? "s" : ""} non lue${totalUnread > 1 ? "s" : ""}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1C3A6B),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final convId = docs[i].id;
                    final hasUnread = _hasUnread(data, convId, user.uid);
                    final rawCount = data['msgUnread_${user.uid}'];
                    final msgCount = (rawCount as num?)?.toInt() ?? 0;

                    final participantNames =
                        (data['participantNames'] as Map<String, dynamic>?) ?? {};
                    final otherName = participantNames.entries
                        .where((e) => e.key != user.uid)
                        .map((e) => e.value.toString())
                        .join(', ');

                    final initials = otherName.isNotEmpty
                        ? otherName
                            .split(' ')
                            .take(2)
                            .map((w) => w.isNotEmpty ? w[0] : '')
                            .join()
                            .toUpperCase()
                        : '?';

                    final lastMsg = data['lastMessage'] as String? ?? '';
                    final lastTime =
                        (data['lastMessageTime'] as dynamic)?.toDate() as DateTime?;

                    final participants = List<String>.from(
                        (data['participants'] as List<dynamic>?) ?? []);
                    final otherId = participants.firstWhere(
                        (p) => p != user.uid, orElse: () => '');

                    return GestureDetector(
                      onTap: () async {
                        await _markRead(convId);
                        // Reset msgUnread dans Firestore
                        FirebaseFirestore.instance
                            .collection(AppConstants.collectionConversations)
                            .doc(convId)
                            .update({'msgUnread_${user.uid}': 0})
                            .catchError((_) {});
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: convId,
                              otherUserId: otherId,
                              otherUserName: otherName,
                            ),
                          ),
                        ).then((_) => _loadLastVisits());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: hasUnread
                              ? Border.all(
                                  color: const Color(0xFF1C3A6B).withOpacity(0.3),
                                  width: 1.5)
                              : null,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: const Color(0xFF1C3A6B),
                                  child: Text(initials,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                                if (hasUnread)
                                  Positioned(
                                    top: -4, right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.white, width: 1.5),
                                      ),
                                      constraints: const BoxConstraints(
                                          minWidth: 18, minHeight: 18),
                                      child: Text(
                                        msgCount > 0
                                            ? (msgCount > 99 ? '99+' : '$msgCount')
                                            : '!',
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
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(otherName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: hasUnread
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: const Color(0xFF1C2A3A),
                                      )),
                                  const SizedBox(height: 3),
                                  Text(lastMsg,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: hasUnread
                                            ? const Color(0xFF1C3A6B)
                                            : Colors.grey.shade500,
                                        fontWeight: hasUnread
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      )),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_formatTime(lastTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasUnread
                                      ? const Color(0xFF1C3A6B)
                                      : Colors.grey.shade400,
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}