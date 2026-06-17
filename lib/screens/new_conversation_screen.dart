import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'chat_screen.dart';

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Génère un ID de conversation unique et stable pour deux utilisateurs
  String _conversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  void _openChat(BuildContext context, AppUser currentUser, String otherId, String otherName) {
    final convId = _conversationId(currentUser.uid, otherId);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: convId,
          otherUserId: otherId,
          otherUserName: otherName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthService>().currentUser;
    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Nouvelle conversation',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1C3A6B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.collectionUsers)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1C3A6B)));
                }

                final docs = snapshot.data?.docs ?? [];

                // Filtrer : exclure soi-même + appliquer la recherche
                final users = docs
                    .map((d) => AppUser.fromMap(d.data() as Map<String, dynamic>, d.id))
                    .where((u) => u.uid != currentUser.uid)
                    .where((u) {
                      if (_searchQuery.isEmpty) return true;
                      return u.fullName.toLowerCase().contains(_searchQuery) ||
                          u.filiere!.toLowerCase().contains(_searchQuery);
                    })
                    .toList();

                if (users.isEmpty) {
                  return const Center(
                    child: Text('Aucun utilisateur trouvé',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  );
                }

                // Grouper par rôle
                final admins = users.where((u) => u.role == UserRole.admin).toList();
                final teachers = users.where((u) => u.role == UserRole.teacher).toList();
                final students = users.where((u) => u.role == UserRole.student).toList();
                final staff = users.where((u) => u.role == UserRole.staff).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (admins.isNotEmpty) ...[
                      _SectionHeader(title: 'Administration', icon: Icons.admin_panel_settings),
                      ...admins.map((u) => _UserTile(
                          user: u,
                          onTap: () => _openChat(context, currentUser, u.uid, u.fullName))),
                      const SizedBox(height: 8),
                    ],
                    if (teachers.isNotEmpty) ...[
                      _SectionHeader(title: 'Enseignants', icon: Icons.school),
                      ...teachers.map((u) => _UserTile(
                          user: u,
                          onTap: () => _openChat(context, currentUser, u.uid, u.fullName))),
                      const SizedBox(height: 8),
                    ],
                    if (students.isNotEmpty) ...[
                      _SectionHeader(title: 'Étudiants', icon: Icons.people),
                      ...students.map((u) => _UserTile(
                          user: u,
                          onTap: () => _openChat(context, currentUser, u.uid, u.fullName))),
                      const SizedBox(height: 8),
                    ],
                    if (staff.isNotEmpty) ...[
                      _SectionHeader(title: 'Staff', icon: Icons.badge_outlined),
                      ...staff.map((u) => _UserTile(
                          user: u,
                          onTap: () => _openChat(context, currentUser, u.uid, u.fullName))),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1C3A6B)),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C3A6B),
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1C3A6B),
              child: Text(user.initials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1C3A6B))),
                  if (user.filiere != null && user.filiere!.isNotEmpty)
                    Text(user.filiere!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF1C3A6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(user.role.label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1C3A6B), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
