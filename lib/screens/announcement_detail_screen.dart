import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const AnnouncementDetailScreen({super.key, required this.id, required this.data});

  static const Map<String, Color> _categoryColors = {
    'Général':   Color(0xFF1C3A6B),
    'Examen':    Color(0xFF9C27B0),
    'Événement': Color(0xFF2196F3),
    'Urgent':    Color(0xFFE53935),
    'Info':      Color(0xFF4CAF50),
  };

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final content = data['content'] ?? '';
    final category = data['category'] ?? 'Général';
    final target = data['targetPublic'] ?? '';
    final authorName = data['authorName'] ?? 'Administration';
    final authorPoste = data['authorPoste'] ?? '';
    final isPinned = data['isPinned'] ?? false;
    final sendNotification = data['sendNotification'] ?? false;
    final fileUrl = data['fileUrl'] as String?;
    final fileType = data['fileType'] as String?;
    final fileName = data['fileName'] as String?;
    final createdAt = data['createdAt'] as Timestamp?;
    final color = _categoryColors[category] ?? const Color(0xFF1C3A6B);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Annonce',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec bordure gauche
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(category.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                                ),
                                if (isPinned) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.push_pin, size: 14, color: color),
                                ],
                                if (sendNotification) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.notifications_active, size: 14, color: Colors.orange),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C2A3A), height: 1.3)),
                            const SizedBox(height: 8),
                            if (target.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.people_outline, size: 13, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(target, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            const SizedBox(height: 14),

            // Auteur + date
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withOpacity(0.15),
                    child: Text(
                      authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(authorName,
                            style: const TextStyle(fontWeight: FontWeight.bold,
                                fontSize: 13, color: Color(0xFF1C2A3A))),
                        if (authorPoste.isNotEmpty)
                          Text(authorPoste, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text(_formatDate(createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Image si présente
            if (fileUrl != null && fileType == 'image') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(fileUrl, width: double.infinity,
                    height: 200, fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null ? child
                        : Container(height: 200, color: Colors.grey.shade200,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
              const SizedBox(height: 14),
            ],

            // Contenu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Text(content,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF2A2A2A), height: 1.8)),
            ),

            // Pièce jointe PDF
            if (fileUrl != null && fileType == 'pdf') ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(fileUrl);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fileName ?? 'Document PDF',
                                style: const TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 13, color: Colors.red)),
                            const Text('Appuyer pour ouvrir',
                                style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.open_in_new, color: Colors.red, size: 18),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}