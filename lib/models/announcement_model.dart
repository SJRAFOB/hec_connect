import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AnnouncementCategory {
  urgent,
  event,
  info,
  schedule;

  String get label {
    switch (this) {
      case AnnouncementCategory.urgent: return 'Urgent';
      case AnnouncementCategory.event: return 'Événement';
      case AnnouncementCategory.info: return 'Information';
      case AnnouncementCategory.schedule: return 'Emploi du temps';
    }
  }

  Color get color {
    switch (this) {
      case AnnouncementCategory.urgent: return const Color(0xFFB12831);
      case AnnouncementCategory.event: return const Color(0xFF5BC0DE);
      case AnnouncementCategory.info: return const Color(0xFF4CAF50);
      case AnnouncementCategory.schedule: return const Color(0xFFFFA726);
    }
  }

  static AnnouncementCategory fromString(String? value) {
    return AnnouncementCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => AnnouncementCategory.info,
    );
  }
}

class Announcement {
  final String id;
  final String titre;
  final String contenu;
  final AnnouncementCategory category;
  final String authorId;
  final String authorName;
  final String? targetFiliere;
  final String? targetNiveau;
  final String? imageUrl;
  final String? fileUrl;
  final DateTime publishedAt;

  Announcement({
    required this.id,
    required this.titre,
    required this.contenu,
    required this.category,
    required this.authorId,
    required this.authorName,
    this.targetFiliere,
    this.targetNiveau,
    this.imageUrl,
    this.fileUrl,
    required this.publishedAt,
  });

  factory Announcement.fromMap(Map<String, dynamic> data, String id) {
    return Announcement(
      id: id,
      titre: data['titre'] ?? '',
      contenu: data['contenu'] ?? '',
      category: AnnouncementCategory.fromString(data['category']),
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      targetFiliere: data['targetFiliere'],
      targetNiveau: data['targetNiveau'],
      imageUrl: data['imageUrl'],
      fileUrl: data['fileUrl'],
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'contenu': contenu,
      'category': category.name,
      'authorId': authorId,
      'authorName': authorName,
      'targetFiliere': targetFiliere,
      'targetNiveau': targetNiveau,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'publishedAt': Timestamp.fromDate(publishedAt),
    };
  }
}