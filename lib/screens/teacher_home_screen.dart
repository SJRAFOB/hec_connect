import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/messaging_badge_card.dart';
import '../widgets/announcements_badge_card.dart';
import 'splash_screen.dart';

class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});

  Stream<int> _unreadStream(String uid) {
    return FirebaseFirestore.instance
        .collection(AppConstants.collectionConversations)
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final unread = Map<String, dynamic>.from(data['unread'] ?? {});
        total += (unread[uid] ?? 0) as int;
      }
      return total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        title: const Text('Espace Enseignant',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()), (_) => false);
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C3A6B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFF1C3A6B),
                    child: Text(user.initials,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 14),
                  Text('Bonjour, Prof. ${user.nom} !',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1C3A6B))),
                  const SizedBox(height: 4),
                  Text(
                    user.matieres.isNotEmpty
                        ? user.matieresFullDisplay
                        : 'Enseignant',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  StreamBuilder<int>(
                    stream: _unreadStream(user.uid),
                    builder: (context, snapshot) {
                      final unread = snapshot.data ?? 0;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.0,
                        children: [
                          const AnnoncesBadgeCard(route: '/annonces'),
                          _card(context, Icons.calendar_today_outlined, 'Mon emploi\ndu temps', '/emploi-du-temps', 0),
                          MessagingBadgeCard(userId: user.uid),
                          _card(context, Icons.person_outline, 'Mon profil', '/profil', 0),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _card(BuildContext ctx, IconData icon, String label, String route, int badge) {
    return GestureDetector(
      onTap: () => Navigator.of(ctx).pushNamed(route),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 36, color: const Color(0xFF1C3A6B)),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C3A6B)),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (badge > 0)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}