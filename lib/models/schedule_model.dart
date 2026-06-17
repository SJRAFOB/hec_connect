import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CourseSession {
  final String matiere;
  final String enseignant;
  final String salle;
  final int dayOfWeek; // 1=Lundi ... 5=Vendredi
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;

  CourseSession({
    required this.matiere,
    required this.enseignant,
    required this.salle,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.color = const Color(0xFF5BC0DE),
  });

  String get timeRange =>
      '${_fmt(startTime)} - ${_fmt(endTime)}';

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  factory CourseSession.fromMap(Map<String, dynamic> data) {
    final start = (data['startTime'] as String? ?? '08:00').split(':');
    final end = (data['endTime'] as String? ?? '10:00').split(':');
    return CourseSession(
      matiere: data['matiere'] ?? '',
      enseignant: data['enseignant'] ?? '',
      salle: data['salle'] ?? '',
      dayOfWeek: data['dayOfWeek'] ?? 1,
      startTime: TimeOfDay(hour: int.parse(start[0]), minute: int.parse(start[1])),
      endTime: TimeOfDay(hour: int.parse(end[0]), minute: int.parse(end[1])),
      color: Color(data['color'] ?? 0xFF5BC0DE),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matiere': matiere,
      'enseignant': enseignant,
      'salle': salle,
      'dayOfWeek': dayOfWeek,
      'startTime': _fmt(startTime),
      'endTime': _fmt(endTime),
      'color': color.value,
    };
  }
}

class Schedule {
  final String id;
  final String filiere;
  final String niveau;
  final DateTime weekStart;
  final String? pdfUrl;
  final List<CourseSession> sessions;
  final DateTime updatedAt;

  Schedule({
    required this.id,
    required this.filiere,
    required this.niveau,
    required this.weekStart,
    this.pdfUrl,
    this.sessions = const [],
    required this.updatedAt,
  });

  List<CourseSession> forDay(int dayOfWeek) =>
      sessions.where((s) => s.dayOfWeek == dayOfWeek).toList()
        ..sort((a, b) => a.startTime.hour.compareTo(b.startTime.hour));

  factory Schedule.fromMap(Map<String, dynamic> data, String id) {
    return Schedule(
      id: id,
      filiere: data['filiere'] ?? '',
      niveau: data['niveau'] ?? '',
      weekStart: (data['weekStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pdfUrl: data['pdfUrl'],
      sessions: ((data['sessions'] as List?) ?? [])
          .map((s) => CourseSession.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'filiere': filiere,
      'niveau': niveau,
      'weekStart': Timestamp.fromDate(weekStart),
      'pdfUrl': pdfUrl,
      'sessions': sessions.map((s) => s.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}