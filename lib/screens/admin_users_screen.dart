// lib/screens/admin_users_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import '../utils/constants.dart';

// URL du serveur de notifications (même serveur que les push)
const _serverUrl = 'https://hec-notify-server.onrender.com';
// Secret injecté au build via --dart-define=ADMIN_SECRET=xxx
// Ne jamais mettre de valeur par défaut ici
const _adminSecret = String.fromEnvironment('ADMIN_SECRET');

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _filterRole = 'tous'; // tous | student | teacher | admin | staff

  final _roleFilters = const [
    {'key': 'tous', 'label': 'Tous'},
    {'key': 'student', 'label': 'Étudiants'},
    {'key': 'teacher', 'label': 'Profs'},
    {'key': 'admin', 'label': 'Admins'},
    {'key': 'staff', 'label': 'Staff'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Données ──────────────────────────────────────────────────────────────

  List<AppUser> _applyFilters(List<QueryDocumentSnapshot> docs) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return docs
        .where((doc) => doc.id != currentUid)
        .map((doc) {
          try {
            return AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (_) {
            return null;
          }
        })
        .whereType<AppUser>()
        .where((u) {
          if (_filterRole != 'tous' && u.role.name != _filterRole) return false;
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return u.fullName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              u.matricule.toLowerCase().contains(q);
        })
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _toggleDisable(AppUser user) async {
    final newState = !(user.isDisabled ?? false);

    // 1. Mettre à jour le champ Firestore
    await _db.collection(AppConstants.collectionUsers).doc(user.uid).update({
      'isDisabled': newState,
    });

    // 2. Désactiver / réactiver le compte Firebase Auth via le serveur
    try {
      await http.post(
        Uri.parse('$_serverUrl/setUserDisabled'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': user.uid,
          'disabled': newState,
          'secret': _adminSecret,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('setUserDisabled error: $e');
      // On continue : le compte Firestore est bloqué ; l'auth Firebase sera cohérent au prochain restart
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newState
            ? '${user.fullName} a été désactivé(e).'
            : '${user.fullName} a été réactivé(e).'),
        backgroundColor:
            newState ? const Color(0xFFB12831) : const Color(0xFF4CAF50),
      ));
    }
  }

  void _confirmDelete(AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce compte'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: 'Supprimer définitivement '),
              TextSpan(
                text: user.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ' ?\n\nLe profil sera supprimé de Firestore. '
                    'La suppression complète du compte Firebase Auth nécessite '
                    'Cloud Functions (plan Blaze).',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB12831),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteUser(user);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(AppUser user) async {
    try {
      // 1. Supprimer le doc Firestore
      await _db.collection(AppConstants.collectionUsers).doc(user.uid).delete();

      // 2. Supprimer l'auth Firebase via le serveur
      final response = await http.post(
        Uri.parse('$_serverUrl/deleteUser'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': user.uid, 'secret': _adminSecret}),
      ).timeout(const Duration(seconds: 10));

      final authDeleted = response.statusCode == 200;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(authDeleted
              ? '${user.fullName} supprimé(e) complètement.'
              : '${user.fullName} supprimé(e) de Firestore (auth: échec).'),
          backgroundColor: authDeleted ? Colors.green : Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur suppression : $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ─── Liaison prof ↔ EDT ───────────────────────────────────────────────────

  Future<void> _linkTeacherToSchedule(AppUser teacher) async {
    final controller = TextEditingController(text: teacher.fullName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lier à l\'emploi du temps'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrez le nom exact du professeur tel qu\'il apparaît dans l\'EDT '
              '(ex: "Mr Kouassi", "Dr Kouakou Richard").',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nom dans l\'EDT',
                border: OutlineInputBorder(),
                hintText: 'Ex: Mr Kouassi',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B3D6E),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lier'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final nomDansEdt = controller.text.trim();
    if (nomDansEdt.isEmpty) return;

    try {
      // Trouver tous les créneaux avec ce professeurNom
      final snap = await _db
          .collection(AppConstants.collectionSchedules)
          .where('professeurNom', isEqualTo: nomDansEdt)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Aucun créneau trouvé pour "$nomDansEdt".'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      // Mettre à jour tous les créneaux en batch
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'professeurId': teacher.uid});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${snap.docs.length} créneau${snap.docs.length > 1 ? 'x' : ''} '
            'lié${snap.docs.length > 1 ? 's' : ''} à ${teacher.fullName}.',
          ),
          backgroundColor: const Color(0xFF4CAF50),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showUserOptions(AppUser user) {
    final isDisabled = user.isDisabled ?? false;
    final isTeacher = user.role == UserRole.teacher;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                _avatarWidget(user, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(user.email,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ]),
                ),
              ]),
            ),
            const Divider(),
            if (isTeacher)
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined,
                    color: Color(0xFF5BC0DE)),
                title: const Text('Lier à l\'emploi du temps',
                    style: TextStyle(color: Color(0xFF5BC0DE))),
                subtitle: const Text('Associer ce prof aux créneaux de l\'EDT',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _linkTeacherToSchedule(user);
                },
              ),
            ListTile(
              leading: Icon(
                isDisabled ? Icons.check_circle_outline : Icons.block,
                color: isDisabled
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFFA726),
              ),
              title: Text(
                isDisabled ? 'Réactiver le compte' : 'Désactiver le compte',
                style: TextStyle(
                    color: isDisabled
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFFA726)),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleDisable(user);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Color(0xFFB12831)),
              title: const Text('Supprimer le compte',
                  style: TextStyle(color: Color(0xFFB12831))),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(user);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _avatarWidget(AppUser user, {double radius = 24}) {
    final isDisabled = user.isDisabled ?? false;
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundImage:
              user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
          backgroundColor:
              isDisabled ? Colors.grey[300] : _roleColor(user.role),
          child: user.photoUrl == null
              ? Text(
                  user.initials,
                  style: TextStyle(
                      color: isDisabled ? Colors.grey : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: radius * 0.6),
                )
              : null,
        ),
        if (isDisabled)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Color(0xFFB12831), shape: BoxShape.circle),
              child: const Icon(Icons.block, color: Colors.white, size: 10),
            ),
          ),
      ],
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return const Color(0xFF1B3D6E);
      case UserRole.teacher:
        return const Color(0xFF5BC0DE);
      case UserRole.admin:
        return const Color(0xFFB12831);
      case UserRole.staff:
        return const Color(0xFF4CAF50);
    }
  }

  Widget _roleBadge(UserRole role) {
    final labels = {
      UserRole.student: 'Étudiant',
      UserRole.teacher: 'Professeur',
      UserRole.admin: 'Admin',
      UserRole.staff: 'Staff',
    };
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        labels[role] ?? role.name,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildUserTile(AppUser user) {
    final isDisabled = user.isDisabled ?? false;

    // Infos secondaires selon le rôle
    final subParts = <String>[
      if (user.niveau != null) user.niveau!,
      if (user.filiere != null) user.filiere!,
      if (user.matieres.isNotEmpty) user.matieres.take(2).join(', '),
    ];
    final sub = subParts.join(' • ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: _avatarWidget(user),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDisabled ? Colors.grey : Colors.black87,
                  decoration:
                      isDisabled ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _roleBadge(user.role),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(
              user.email,
              style: TextStyle(
                  fontSize: 12,
                  color: isDisabled ? Colors.grey : Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
            if (user.matricule.isNotEmpty)
              Text(user.matricule,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: TextStyle(
                    fontSize: 11,
                    color: isDisabled
                        ? Colors.grey[400]
                        : const Color(0xFF5BC0DE)),
                overflow: TextOverflow.ellipsis,
              ),
            if (isDisabled)
              const Text(
                'COMPTE DÉSACTIVÉ',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB12831),
                    letterSpacing: 0.5),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onPressed: () => _showUserOptions(user),
        ),
        onTap: () => _showUserOptions(user),
      ),
    );
  }

  // ─── Build principal ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3D6E),
        foregroundColor: Colors.white,
        title: const Text('Gestion des utilisateurs'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: const Color(0xFF1B3D6E),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, email, matricule...',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),

          // Filtres rôle
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _roleFilters.map((f) {
                  final selected = _filterRole == f['key'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f['label']!),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _filterRole = f['key']!),
                      selectedColor: const Color(0xFF1B3D6E)
                          .withValues(alpha: 0.15),
                      checkmarkColor: const Color(0xFF1B3D6E),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF1B3D6E)
                            : Colors.black54,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Liste utilisateurs
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _db.collection(AppConstants.collectionUsers).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1B3D6E)));
                }

                final users = _applyFilters(snap.data!.docs);

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search,
                            size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Aucun utilisateur dans cette catégorie'
                              : 'Aucun résultat pour "$_searchQuery"',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            '${users.length} utilisateur${users.length > 1 ? 's' : ''}',
                            style: const TextStyle(
             