import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'splash_screen.dart';
import 'seed_schedule_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

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
      backgroundColor: const Color(0xFF1C3A6B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        elevation: 0,
        title: const Text('Administration',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings,
                        size: 42, color: Color(0xFF1C3A6B)),
                  ),
                  const SizedBox(height: 12),
                  Text('Bienvenue, ${user.prenom} !',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(user.poste ?? 'Administration HEC Abidjan',
                      style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 28),

                  StreamBuilder<int>(
                    stream: _unreadStream(user.uid),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.0,
                        children: [
                          _card(context, Icons.people_outline, 'Utilisateurs', '/admin-users', 0),
                          _AdminAnnoncesCard(userId: user.uid),
                          _card(context, Icons.calendar_today_outlined, 'Emploi du temps', '/emploi-du-temps', 0),
                          _card(context, Icons.chat_bubble_outline, 'Messagerie', '/messagerie', unreadCount),
                          _card(context, Icons.bar_chart_outlined, 'Statistiques', '/stats', 0),
                          _card(context, Icons.person_outline, 'Mon profil', '/profil', 0),
                          _cardAction(context, Icons.upload_outlined, 'Import EDT', () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const SeedScheduleScreen()));
                          }, 0),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _cardAction(BuildContext ctx, IconData icon, String label, VoidCallback onTap, int badge) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: Colors.white),
                textAlign: TextAlign.center, maxLines: 2),
          ])),
        ),
      ]),
    );
  }

  Widget _card(BuildContext ctx, IconData icon, String label, String route, int badge) {
    return GestureDetector(
      onTap: () => Navigator.of(ctx).pushNamed(route),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 36, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

}

class _AdminAnnoncesCard extends StatefulWidget {
  final String userId;
  const _AdminAnnoncesCard({required this.userId});
  @override
  State<_AdminAnnoncesCard> createState() => _AdminAnnoncesCardState();
}

class _AdminAnnoncesCardState extends State<_AdminAnnoncesCard> {
  DateTime? _lastSeen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('lastSeenAnnouncements');
    if (ms != null && mounted) {
      setState(() => _lastSeen = DateTime.fromMillisecondsSinceEpoch(ms));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.collectionAnnouncements)
          .snapshots(),
      builder: (context, snap) {
        int count = 0;
        for (final d in snap.data?.docs ?? []) {
          final data = d.data() as Map<String, dynamic>;
          final ts = (data['createdAt'] as dynamic)?.toDate() as DateTime?;
          if (ts != null && (_lastSeen == null || ts.isAfter(_lastSeen!))) {
            count++;
          }
        }
        return GestureDetector(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final now = DateTime.now();
            await prefs.setInt('lastSeenAnnouncements', now.millisecondsSinceEpoch);
            if (mounted) setState(() => _lastSeen = now);
            if (context.mounted) Navigator.of(context).pushNamed('/annonces');
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_outlined, size: 36, color: Colors.white),
                      SizedBox(height: 10),
                      Text('Annonces', style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: Colors.white),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(count > 99 ? '99+' : '$count',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}