import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

// Widget carte Annonces avec badge qui se remet à jour automatiquement
class AnnoncesBadgeCard extends StatefulWidget {
  final String route;
  final IconData icon;
  final String label;

  const AnnoncesBadgeCard({
    super.key,
    required this.route,
    this.icon = Icons.campaign_outlined,
    this.label = 'Annonces',
  });

  @override
  State<AnnoncesBadgeCard> createState() => _AnnoncesBadgeCardState();
}

class _AnnoncesBadgeCardState extends State<AnnoncesBadgeCard> {
  int _badgeCount = 0;
  DateTime? _lastSeen;

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
  }

  Future<void> _loadLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('lastSeenAnnouncements');
    if (ms != null) {
      setState(() {
        _lastSeen = DateTime.fromMillisecondsSinceEpoch(ms);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.collectionAnnouncements)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        for (final doc in snapshot.data?.docs ?? []) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = (data['createdAt'] as dynamic)?.toDate() as DateTime?;
          if (ts != null) {
            if (_lastSeen == null || ts.isAfter(_lastSeen!)) {
              count++;
            }
          }
        }

        return GestureDetector(
          onTap: () async {
            // Sauvegarder le moment de lecture
            final prefs = await SharedPreferences.getInstance();
            final now = DateTime.now();
            await prefs.setInt(
                'lastSeenAnnouncements', now.millisecondsSinceEpoch);
            setState(() => _lastSeen = now);
            if (context.mounted) {
              Navigator.of(context).pushNamed(widget.route);
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon,
                          size: 32, color: const Color(0xFF1C3A6B)),
                      const SizedBox(height: 10),
                      Text(
                        widget.label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C3A6B)),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 8,
                  right: 8,
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
                      count > 99 ? '99+' : '$count',
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
