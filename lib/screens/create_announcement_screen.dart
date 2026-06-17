import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});
  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _selectedCategory = 'Général';
  List<String> _selectedTargets = ['Tous les utilisateurs'];
  bool _isPinned = false;
  bool _sendNotification = true;
  bool _isLoading = false;

  File? _attachedFile;
  String? _attachedFileName;

  final List<String> _categories = ['Général', 'Examen', 'Événement', 'Urgent', 'Info'];

  final Map<String, List<String>> _targetGroups = {
    'Général': ['Tous les utilisateurs'],
    'Par rôle': [
      'Étudiants uniquement',
      'Enseignants uniquement',
      'Administration',
      'Staff',
    ],
    'Par niveau': [
      'Bachelor 1', 'Bachelor 2', 'Bachelor 3',
      'Master 1', 'Master 2', 'MBA', 'DBA',
    ],
    'Par filière': [
      'Marketing', 'Finance et Comptabilité', 'Informatique',
      'Droit des Affaires', 'Gestion des Ressources Humaines',
      'Communication Digitale', 'Management',
    ],
  };

  static const Map<String, Color> _categoryColors = {
    'Général':   Color(0xFF1C3A6B),
    'Examen':    Color(0xFF9C27B0),
    'Événement': Color(0xFF2196F3),
    'Urgent':    Color(0xFFE53935),
    'Info':      Color(0xFF4CAF50),
  };

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Joindre une image',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                      color: Color(0xFF1C3A6B))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _fileOption(Icons.image_outlined, 'Galerie', Colors.blue, () async {
                    Navigator.pop(context);
                    final f = await ImagePicker().pickImage(
                        source: ImageSource.gallery, imageQuality: 75);
                    if (f != null) {
                      setState(() {
                        _attachedFile = File(f.path);
                        _attachedFileName = f.name;
                      });
                    }
                  }),
                  _fileOption(Icons.camera_alt_outlined, 'Caméra', Colors.teal, () async {
                    Navigator.pop(context);
                    final f = await ImagePicker().pickImage(
                        source: ImageSource.camera, imageQuality: 75);
                    if (f != null) {
                      setState(() {
                        _attachedFile = File(f.path);
                        _attachedFileName = f.name;
                      });
                    }
                  }),
                  if (_attachedFile != null)
                    _fileOption(Icons.delete_outline, 'Supprimer', Colors.grey.shade600, () {
                      Navigator.pop(context);
                      setState(() {
                        _attachedFile = null;
                        _attachedFileName = null;
                      });
                    }),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<String?> _uploadFile() async {
    if (_attachedFile == null) return null;
    return await CloudinaryService.upload(_attachedFile!, 'image', context: 'announcement');
  }

  void _showTargetPicker() {
    List<String> tempSelected = List.from(_selectedTargets);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context2, setModal) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Public concerné',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                            color: Color(0xFF1C3A6B))),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setModal(() => tempSelected
                        ..clear()
                        ..add('Tous les utilisateurs')),
                      child: const Text('Réinitialiser',
                          style: TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              if (tempSelected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                        Text(
                          '${tempSelected.length} sélectionné(s) : '
                          '${tempSelected.take(2).join(', ')}'
                          '${tempSelected.length > 2 ? '...' : ''}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1C3A6B),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: _targetGroups.entries.map((group) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                        child: Text(group.key,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500, letterSpacing: 0.5)),
                      ),
                      ...group.value.map((item) {
                        final isSel = tempSelected.contains(item);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setModal(() {
                              if (item == 'Tous les utilisateurs') {
                                tempSelected
                                  ..clear()
                                  ..add('Tous les utilisateurs');
                              } else {
                                tempSelected.remove('Tous les utilisateurs');
                                isSel
                                    ? tempSelected.remove(item)
                                    : tempSelected.add(item);
                                if (tempSelected.isEmpty) {
                                  tempSelected.add('Tous les utilisateurs');
                                }
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF1C3A6B).withValues(alpha: 0.08)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel
                                    ? const Color(0xFF1C3A6B)
                                    : Colors.grey.shade200,
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(item,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: isSel
                                              ? const Color(0xFF1C3A6B)
                                              : Colors.black87,
                                          fontWeight: isSel
                                              ? FontWeight.w600
                                              : FontWeight.normal)),
                                ),
                                Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? const Color(0xFF1C3A6B)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: isSel
                                            ? const Color(0xFF1C3A6B)
                                            : Colors.grey.shade400),
                                  ),
                                  child: isSel
                                      ? const Icon(Icons.check,
                                      color: Colors.white, size: 14)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  )).toList(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _selectedTargets = List.from(tempSelected));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A6B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Confirmer (${tempSelected.length})',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      final fileUrl = await _uploadFile();

      await FirebaseFirestore.instance
          .collection(AppConstants.collectionAnnouncements)
          .add({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _selectedCategory,
        'targetPublic': _selectedTargets.join(', '),
        'isPinned': _isPinned,
        'sendNotification': _sendNotification,
        'fileUrl': fileUrl,
        'fileType': _attachedFile != null ? 'image' : null,
        'fileName': _attachedFileName,
        'authorId': user.uid,
        'authorName': user.fullName,
        'authorPoste': user.poste ?? user.role.label,
        'authorRole': user.role.name,
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Annonce publiée !'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final roleLabel =
    user?.role == UserRole.teacher ? 'ENSEIGNANT' : 'ADMIN';
    final roleColor =
    user?.role == UserRole.teacher ? Colors.blue : Colors.orange;
    final selectedColor =
        _categoryColors[_selectedCategory] ?? const Color(0xFF1C3A6B);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Nouvelle annonce',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Badge rôle
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                  Border.all(color: roleColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        user?.role == UserRole.teacher
                            ? Icons.school_outlined
                            : Icons.admin_panel_settings_outlined,
                        size: 14,
                        color: roleColor),
                    const SizedBox(width: 6),
                    Text(roleLabel,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: roleColor)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Titre
              _label('Titre de l\'annonce *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration:
                _inputDecoration('Ex: Reprise des cours - Licence 3'),
                validator: (v) =>
                v == null || v.isEmpty ? 'Titre requis' : null,
              ),
              const SizedBox(height: 16),

              // Catégorie
              _label('Catégorie *'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: _inputDecoration(''),
                items: _categories.map((c) {
                  final color = _categoryColors[c]!;
                  return DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(c),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 16),

              // Public concerné
              _label('Public concerné *'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _showTargetPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _selectedTargets.isEmpty
                            ? Text(
                          'Choisir le(s) public(s) cible(s)',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13),
                        )
                            : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedTargets
                              .map((t) => Container(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C3A6B)
                                  .withValues(alpha: 0.1),
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: Text(t,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1C3A6B),
                                    fontWeight:
                                    FontWeight.w600)),
                          ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.expand_more,
                          color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Contenu
              _label('Contenu *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contentController,
                maxLines: 6,
                decoration: _inputDecoration(
                    'Rédigez le contenu de votre annonce...'),
                validator: (v) =>
                v == null || v.isEmpty ? 'Contenu requis' : null,
              ),
              const SizedBox(height: 16),

              // Joindre image (plus de PDF)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _attachedFile != null
                          ? selectedColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: _attachedFile == null
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined,
                          color: Colors.grey.shade500, size: 20),
                      const SizedBox(width: 8),
                      Text('Joindre une image (optionnel)',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14)),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, color: selectedColor, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _attachedFileName ?? 'Image jointe',
                          style: TextStyle(
                              color: selectedColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                    ],
                  ),
                ),
              ),
              if (_attachedFile != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_attachedFile!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 16),

              // Options
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6)
                  ],
                ),
                child: Column(
                  children: [
                    _switchRow(
                      icon: Icons.push_pin_outlined,
                      iconColor: const Color(0xFF1C3A6B),
                      title: 'Épingler l\'annonce',
                      subtitle: 'Affichée en premier pour tous',
                      value: _isPinned,
                      activeColor: const Color(0xFF1C3A6B),
                      onChanged: (v) => setState(() => _isPinned = v),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    _switchRow(
                      icon: Icons.notifications_active_outlined,
                      iconColor: Colors.orange,
                      title: 'Envoyer une notification push',
                      subtitle: _sendNotification
                          ? 'Tous les utilisateurs seront notifiés'
                          : 'Aucune notification envoyée',
                      value: _sendNotification,
                      activeColor: Colors.orange,
                      onChanged: (v) =>
                          setState(() => _sendNotification = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Bouton publier
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _publish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C3A6B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Publier l\'annonce',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C2A3A)));

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
        const BorderSide(color: Color(0xFF1C3A6B), width: 1.5)),
  );

  Widget _switchRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1C2A3A))),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: value ? iconColor : Colors.grey)),
              ],
            ),
          ),
          Switch(
              value: value,
              activeThumbColor: activeColor,
              onChanged: onChanged),
        