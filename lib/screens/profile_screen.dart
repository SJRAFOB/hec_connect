import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  late TextEditingController _prenomController;
  late TextEditingController _nomController;
  String? _selectedFiliere;
  String? _selectedNiveau;
  List<String> _selectedMatieres = [];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _prenomController = TextEditingController(text: user?.prenom ?? '');
    _nomController = TextEditingController(text: user?.nom ?? '');
    _selectedFiliere = user?.filiere;
    _selectedNiveau = user?.niveau;
    _selectedMatieres = List.from(user?.matieres ?? []);
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    super.dispose();
  }

  // ── Changer photo ──
  Future<void> _changePhoto() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await CloudinaryService.upload(File(file.path), 'image', context: 'profile');
      if (!mounted) return;
      await FirebaseFirestore.instance
          .collection(AppConstants.collectionUsers)
          .doc(user.uid)
          .set({'photoUrl': url}, SetOptions(merge: true));
      if (!mounted) return;
      auth.updateCurrentUserInMemory(user.copyWith(photoUrl: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo mise à jour ✅'),
            backgroundColor: Color(0xFF1C3A6B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur photo : $e'),
              backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Sauvegarder ──
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final updated = user.copyWith(
        prenom: _prenomController.text.trim(),
        nom: _nomController.text.trim(),
        filiere: _selectedFiliere,
        niveau: _selectedNiveau,
        matieres: _selectedMatieres,
      );
      await auth.updateProfile(updated);
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour !'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sauvegarde')));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // ── Sélecteur multi-matières (profs) ──
  void _showMatieresPicker() {
    List<String> tempSelected = List.from(_selectedMatieres);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Matières enseignées',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                            color: Color(0xFF1C3A6B))),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setModal(() => tempSelected.clear()),
                      child: const Text('Effacer',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              if (tempSelected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C3A6B).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Color(0xFF1C3A6B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${tempSelected.length} matière(s) sélectionnée(s)',
                            style: const TextStyle(fontSize: 11,
                                color: Color(0xFF1C3A6B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: AppConstants.matieresByDomaine.entries.map((domain) =>
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                          child: Row(
                            children: [
                              Container(width: 3, height: 14,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF1C3A6B),
                                      borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              Text(domain.key,
                                  style: const TextStyle(fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1C3A6B))),
                            ],
                          ),
                        ),
                        ...domain.value.map((matiere) {
                          final isSel = tempSelected.contains(matiere);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setModal(() => isSel
                                ? tempSelected.remove(matiere)
                                : tempSelected.add(matiere)),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFF1C3A6B).withValues(alpha: 0.08)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF1C3A6B) : Colors.grey.shade200,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(matiere,
                                        style: TextStyle(fontSize: 13,
                                            color: isSel ? const Color(0xFF1C3A6B) : Colors.black87,
                                            fontWeight: isSel ? FontWeight.w600 : FontWeight.normal)),
                                  ),
                                  Container(
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(
                                      color: isSel ? const Color(0xFF1C3A6B) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                          color: isSel ? const Color(0xFF1C3A6B) : Colors.grey.shade400),
                                    ),
                                    child: isSel
                                        ? const Icon(Icons.check, color: Colors.white, size: 13)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ).toList(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16,
                    MediaQuery.of(context).viewInsets.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _selectedMatieres = List.from(tempSelected));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A6B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Confirmer (${tempSelected.length})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Changer mot de passe ──
  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true, obscureNew = true, obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20,
              MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const Text('Changer le mot de passe',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      color: Color(0xFF1C3A6B))),
              const SizedBox(height: 20),
              _pwdField('Mot de passe actuel', currentCtrl, obscureCurrent,
                  () => setModal(() => obscureCurrent = !obscureCurrent)),
              const SizedBox(height: 12),
              _pwdField('Nouveau mot de passe', newCtrl, obscureNew,
                  () => setModal(() => obscureNew = !obscureNew)),
              const SizedBox(height: 12),
              _pwdField('Confirmer le nouveau', confirmCtrl, obscureConfirm,
                  () => setModal(() => obscureConfirm = !obscureConfirm)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C3A6B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (newCtrl.text != confirmCtrl.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Les mots de passe ne correspondent pas')));
                      return;
                    }
                    if (newCtrl.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Minimum 6 caractères')));
                      return;
                    }
                    try {
                      final fbUser = FirebaseAuth.instance.currentUser!;
                      final cred = EmailAuthProvider.credential(
                          email: fbUser.email!, password: currentCtrl.text);
                      await fbUser.reauthenticateWithCredential(cred);
                      await fbUser.updatePassword(newCtrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mot de passe modifié !'),
                              backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mot de passe actuel incorrect')));
                      }
                    }
                  },
                  child: const Text('Modifier',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pwdField(String label, TextEditingController ctrl,
      bool obscure, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey),
            onPressed: toggle),
      ),
    );
  }

  // ── Déconnexion ──
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthService>().signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (_) => false);
              }
            },
            child: const Text('Déconnecter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1C3A6B))));
    }

    final isStudent = user.role == UserRole.student;
    final isTeacher = user.role == UserRole.teacher;
    final isAdmin = user.role == UserRole.admin;
    final isStaff = user.role == UserRole.staff;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Mon profil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Sauvegarder',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [

            // ── En-tête bleu avec avatar ──
            Container(
              width: double.infinity,
              color: const Color(0xFF1C3A6B),
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _changePhoto,
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: user.photoUrl != null
                              ? CachedNetworkImageProvider(user.photoUrl!)
                              : null,
                          child: user.photoUrl == null
                              ? Text(user.initials,
                                  style: const TextStyle(fontSize: 36,
                                      fontWeight: FontWeight.bold, color: Colors.white))
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: GestureDetector(
                          onTap: _changePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: _isUploadingPhoto
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Color(0xFF1C3A6B)))
                                : const Icon(Icons.camera_alt,
                                    size: 14, color: Color(0xFF1C3A6B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(user.fullName,
                      style: const TextStyle(fontSize: 20,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(user.poste ?? user.role.label,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  Text(user.email,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Informations personnelles ──
                  _sectionTitle('Informations personnelles'),
                  const SizedBox(height: 10),
                  _card(children: [
                    _isEditing
                        ? _editRow(Icons.person_outline, 'Prénom', _prenomController)
                        : _infoRow(Icons.person_outline, 'Prénom', user.prenom),
                    _divider(),
                    _isEditing
                        ? _editRow(Icons.person_outline, 'Nom', _nomController)
                        : _infoRow(Icons.person_outline, 'Nom', user.nom),
                    _divider(),
                    _lockedRow(Icons.email_outlined, 'Email', user.email),
                    if (isStudent && user.matricule.isNotEmpty) ...[
                      _divider(),
                      _lockedRow(Icons.badge_outlined, 'Matricule', user.matricule),
                    ],
                  ]),

                  const SizedBox(height: 20),

                  // ── Académique (étudiant) ──
                  if (isStudent) ...[
                    _sectionTitle('Informations académiques'),
                    const SizedBox(height: 10),
                    _card(children: [
                      _isEditing
                          ? _dropdownRow(Icons.bar_chart_outlined, 'Niveau',
                              AppConstants.niveaux,
                              AppConstants.niveaux.contains(_selectedNiveau)
                                  ? _selectedNiveau
                                  : AppConstants.niveaux.contains(
                                      (_selectedNiveau ?? '').replaceAll('Bachelor', 'Licence'))
                                      ? (_selectedNiveau ?? '').replaceAll('Bachelor', 'Licence')
                                      : null,
                              (v) => setState(() {
                                _selectedNiveau = v;
                                _selectedFiliere = null;
                              }))
                          : _infoRow(Icons.bar_chart_outlined, 'Niveau',
                              (user.niveau ?? 'Non renseigné')
                                  .replaceAll('Bachelor', 'Licence')),
                      _divider(),
                      _isEditing
                          ? _dropdownRow(Icons.school_outlined, 'Filière',
                              AppConstants.getFilieresByNiveau(
                                  _selectedNiveau ?? user.niveau),
                              _selectedFiliere,
                              (v) => setState(() => _selectedFiliere = v))
                          : _infoRow(Icons.school_outlined, 'Filière',
                              user.filiere ?? 'Non renseignée'),
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // ── Matières (professeur) ──
                  if (isTeacher) ...[
                    Row(
                      children: [
                        Expanded(child: _sectionTitle('Matières enseignées')),
                        if (_isEditing)
                          GestureDetector(
                            onTap: _showMatieresPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C3A6B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.white, size: 13),
                                  SizedBox(width: 4),
                                  Text('Modifier', style: TextStyle(
                                      color: Colors.white, fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: (_isEditing ? _selectedMatieres : user.matieres).isEmpty
                          ? GestureDetector(
                              onTap: _isEditing ? _showMatieresPicker : null,
                              child: const Text('Aucune matière renseignée — appuyez pour ajouter',
                                  style: TextStyle(color: Colors.grey, fontSize: 13)),
                            )
                          : Wrap(
                              spacing: 8, runSpacing: 8,
                              children: (_isEditing ? _selectedMatieres : user.matieres)
                                  .map((m) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C3A6B).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: const Color(0xFF1C3A6B).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.menu_book_outlined,
                                            size: 13, color: Color(0xFF1C3A6B)),
                                        const SizedBox(width: 5),
                                        Text(m, style: const TextStyle(fontSize: 12,
                                            color: Color(0xFF1C3A6B),
                                            fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  )).toList(),
                            ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Poste (admin/staff) ──
                  if (isAdmin || isStaff) ...[
                    _sectionTitle('Informations professionnelles'),
                    const SizedBox(height: 10),
                    _card(children: [
                      _lockedRow(Icons.work_outline, 'Poste',
                          user.poste ?? 'Non renseigné'),
                      _divider(),
                      _lockedRow(Icons.admin_panel_settings_outlined, 'Rôle',
                          user.role.label),
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // ── Sécurité ──
                  _sectionTitle('Sécurité'),
                  const SizedBox(height: 10),
                  _card(children: [
                    _actionRow(
                      icon: Icons.lock_outline,
                      label: 'Changer le mot de passe',
                      onTap: _showChangePassword,
                    ),
                    _divider(),
                    _actionRow(
                      icon: Icons.logout,
                      label: 'Se déconnecter',
                      color: Colors.red,
                      onTap: _confirmLogout,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Annuler (mode édition) ──
                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          final user = context.read<AuthService>().currentUser;
                          setState(() {
                            _isEditing = false;
                            _selectedFiliere = user?.filiere;
                            _selectedNiveau = user?.niveau;
                            _selectedMatieres = List.from(user?.matieres ?? []);
                            _prenomController.text = user?.prenom ?? '';
                            _nomController.text = user?.nom ?? '';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Annuler',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets helpers ──

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
          color: Colors.grey.shade500, letterSpacing: 0.5));

  Widget _card({required List<Widget> children}) => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: children));

  Widget _divider() => Divider(height: 1, indent: 50, color: Colors.grey.shade100);

  Widget _infoRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF1C3A6B)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14,
              color: Color(0xFF1C2A3A), fontWeight: FontWeight.w500)),
        ]),
      ]));

  Widget _lockedRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14,
                color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ]),
        ),
        Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade300),
      ]));

  Widget _editRow(IconData icon, String label, TextEditingController ctrl) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF1C3A6B)),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1C3A6B))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1C3A6B), width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ),
      ]));

  Widget _dropdownRow(IconData icon, String label, List<String> items,
      String? value, ValueChanged<String?> onChanged) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF1C3A6B)),
        const SizedBox(width: 14),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: items.contains(value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1C3A6B))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            items: items.map((i) => DropdownMenuItem(value: i,
                child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ]));

  Widget _actionRow({required IconData icon, required String label,
      required VoidCallback onTap, Color color = const Color(0xFF1C3A6B)}) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14,
                color: color, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ]),
  