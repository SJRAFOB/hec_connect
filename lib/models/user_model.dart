// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  student,
  teacher,
  admin,
  staff;

  String get label {
    switch (this) {
      case UserRole.student: return 'Étudiant';
      case UserRole.teacher: return 'Enseignant';
      case UserRole.admin:   return 'Administration';
      case UserRole.staff:   return 'Staff';
    }
  }

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.student,
    );
  }
}

class AppUser {
  final String uid;
  final String nom;
  final String prenom;
  final String email;
  final String matricule;
  final UserRole role;
  final String? filiere;
  final String? niveau;
  final List<String> matieres;
  final String? poste;
  final String? photoUrl;
  final String? fcmToken;
  final DateTime createdAt;
  final bool? isDisabled; // true = compte désactivé par admin

  AppUser({
    required this.uid,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.matricule,
    required this.role,
    this.filiere,
    this.niveau,
    this.matieres = const [],
    this.poste,
    this.photoUrl,
    this.fcmToken,
    required this.createdAt,
    this.isDisabled,
  });

  String get fullName => '$prenom $nom';

  String get initials {
    final p = prenom.isNotEmpty ? prenom[0] : '';
    final n = nom.isNotEmpty ? nom[0] : '';
    return '$p$n'.toUpperCase();
  }

  String get matieresDisplay {
    if (matieres.isEmpty) return 'Enseignant';
    if (matieres.length == 1) return matieres[0];
    return '${matieres[0]} +${matieres.length - 1}';
  }

  String get matieresFullDisplay => matieres.join(' • ');

  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    List<String> matieres = [];
    if (data['matieres'] != null) {
      matieres = List<String>.from(data['matieres']);
    } else if (data['filiere'] != null &&
        UserRole.fromString(data['role']) == UserRole.teacher) {
      matieres = [data['filiere'] as String];
    }

    return AppUser(
      uid: uid,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      email: data['email'] ?? '',
      matricule: data['matricule'] ?? '',
      role: UserRole.fromString(data['role']),
      filiere: data['filiere'],
      niveau: data['niveau'],
      matieres: matieres,
      poste: data['poste'],
      photoUrl: data['photoUrl'],
      fcmToken: data['fcmToken'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDisabled: data['isDisabled'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'matricule': matricule,
      'role': role.name,
      'filiere': filiere,
      'niveau': niveau,
      'matieres': matieres,
      'poste': poste,
      'photoUrl': photoUrl,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDisabled': isDisabled ?? false,
    };
  }

  AppUser copyWith({
    String? nom, String? prenom, String? email, String? matricule,
    UserRole? role, String? filiere, String? niveau,
    List<String>? matieres, String? poste,
    String? photoUrl, String? fcmToken,
    bool? isDisabled,
  }) {
    return AppUser(
      uid: uid,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      matricule: matricule ?? this.matricule,
      role: role ?? this.role,
      filiere: filiere ?? this.filiere,
      niveau: niveau ?? this.niveau,
      matieres: matieres ?? this.matieres,
      poste: poste ?? this.poste,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      isDisabled: isDisabled ?? this.isDisabled,
    );
  }
}