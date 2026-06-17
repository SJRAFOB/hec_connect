import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'announcement_detail_screen.dart';
import 'create_announcement_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const Map<String, Color> _categoryColors = {
    'Général':   Color(0xFF1C3A6B),
    'Examen':    Color(0xFF9C27B0),
    'Événement': Color(0xFF2196F3),
    'Urgent':    Color(0xFFE53935),
    'Info':      Color(0xFF4CAF50),
  };

  bool _canCreate(AppUser? user) {
    if (user == null) return false;
    if (user.role == UserRole.staff || user.role == UserRole.student) return false;
    return true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        title: const Text('Annonces',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: _canCreate(user)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1C3A6B),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nouvelle annonce',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateAnnouncementScreen())),
            )
          : null,
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher une annonce...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Liste annonces
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.collectionAnnouncements)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1C3A6B)));
                }

                var docs = snapshot.data?.docs ?? [];

                // Trier côté client : épinglées en premier, puis par date
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aPinned = (aData['isPinned'] ?? false) as bool;
                  final bPinned = (bData['isPinned'] ?? false) as bool;
                  if (aPinned != bPinned) return aPinned ? -1 : 1;
                  final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                  final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                  return bTime.compareTo(aTime);
                });

                // Trier côté client : épinglées en premier, puis par date
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aPinned = (aData['isPinned'] ?? false) as bool;
                  final bPinned = (bData['isPinned'] ?? false) as bool;
                  if (aPinned != bPinned) return aPinned ? -1 : 1;
                  final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                  final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                  return bTime.compareTo(aTime);
                });

                // Filtrer par recherche
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '').toLowerCase();
                    final content = (data['content'] ?? '').toLowerCase();
                    return title.contains(_searchQuery) || content.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Aucune annonce trouvée',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    return _AnnouncementCard(
                      id: id,
                      data: data,
                      canDelete: _canCreate(user),
                      categoryColors: _categoryColors,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool canDelete;
  final Map<String, Color> categoryColors;

  const _AnnouncementCard({
    required this.id, required this.data,
    required this.canDelete, required this.categoryColors,
  });

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin',
        'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'annonce'),
        content: const Text('Cette action est irréversible. Confirmer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection(AppConstants.collectionAnnouncements)
                  .doc(id).delete();
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final content = data['content'] ?? '';
    final category = data['category'] ?? 'Général';
    final target = data['targetPublic'] ?? '';
    final isPinned = data['isPinned'] ?? false;
    final createdAt = data['createdAt'] as Timestamp?;
    final color = categoryColors[category] ?? const Color(0xFF1C3A6B);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(id: id, data: data))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bordure gauche colorée
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // Contenu
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C2A3A))),
                          ),
                          const SizedBox(width: 8),
                          // Badge catégorie
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(category.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(_formatDate(createdAt),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          if (isPinned) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.push_pin, size: 11, color: color),
                            const SizedBox(width: 2),
                            Text('Épinglée',
                                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                          ],
                          if (target.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.people_outline, size: 11, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(target,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                            ),
                          ],
                          const Spacer(),
                          if (canDelete)
                            GestureDetector(
                              onTap: () => _confirmDelete(context),
                              child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}