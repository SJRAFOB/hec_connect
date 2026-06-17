import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class CreateScheduleScreen extends StatefulWidget {
  const CreateScheduleScreen({super.key});
  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salleController = TextEditingController();

  String? _selectedJour;
  String? _selectedSlot;
  String? _selectedMatiere;
  String? _selectedFiliere;
  String? _selectedNiveau;
  bool _isLoading = false;

  final List<String> _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

  static const List<Map<String, String>> _slots = [
    {'label': '8h00 - 10h00',   'key': '8h00-10h00'},
    {'label': '10h30 - 12h00',  'key': '10h30-12h00'},
    {'label': '13h00 - 15h00',  'key': '13h00-15h00'},
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    // Prof : matières pré-remplies depuis son profil
    if (user?.role == UserRole.teacher && user!.matieres.isNotEmpty) {
      _selectedMatiere = user.matieres.first;
    }
  }

  @override
  void dispose() {
    _salleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      // Vérifier si le créneau est déjà pris pour cette filière/niveau
      final existing = await FirebaseFirestore.instance
          .collection(AppConstants.collectionSchedules)
          .where('filiere', isEqualTo: _selectedFiliere)
          .where('niveau', isEqualTo: _selectedNiveau)
          .where('jour', isEqualTo: _selectedJour)
          .where('slot', isEqualTo: _selectedSlot)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ce créneau est déjà occupé pour $_selectedFiliere - $_selectedNiveau'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection(AppConstants.collectionSchedules)
          .add({
        'filiere': _selectedFiliere,
        'niveau': _selectedNiveau,
        'jour': _selectedJour,
        'slot': _selectedSlot,
        'matiere': _selectedMatiere,
        'professeurId': user.uid,
        'professeurNom': user.fullName,
        'salle': _salleController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cours ajouté !'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sauvegarde')));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isTeacher = user?.role == UserRole.teacher;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A6B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Ajouter un cours',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Enregistrer',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Aperçu du créneau ──
              if (_selectedJour != null && _selectedSlot != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C3A6B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_selectedJour!,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(_slots.firstWhere((s) => s['key'] == _selectedSlot)['label']!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ]),
                ),

              // ── Jour ──
              _label('Jour *'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _jours.map((j) {
                  final isSelected = _selectedJour == j;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedJour = j),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1C3A6B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1C3A6B) : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(j, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Créneau ──
              _label('Créneau horaire *'),
              const SizedBox(height: 8),
              Column(
                children: _slots.map((slot) {
                  final isSelected = _selectedSlot == slot['key'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlot = slot['key']),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1C3A6B).withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1C3A6B) : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1C3A6B) : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isSelected ? const Color(0xFF1C3A6B) : Colors.grey.shade400),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 13)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 18,
                            color: isSelected ? const Color(0xFF1C3A6B) : Colors.grey),
                        const SizedBox(width: 8),
                        Text(slot['label']!,
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: isSelected ? const Color(0xFF1C3A6B) : Colors.black87,
                            )),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Filière + Niveau ──
              _label('Niveau *'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedNiveau,
                isExpanded: true,
                decoration: _inputDeco('Choisir le niveau'),
                items: AppConstants.niveaux.map((n) =>
                    DropdownMenuItem(value: n, child: Text(n))).toList(),
                onChanged: (v) => setState(() {
                  _selectedNiveau = v;
                  _selectedFiliere = null;
                }),
                validator: (v) => v == null ? 'Niveau requis' : null,
              ),
              const SizedBox(height: 14),

              _label('Filière *'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: AppConstants.getFilieresByNiveau(_selectedNiveau)
                    .contains(_selectedFiliere) ? _selectedFiliere : null,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: _selectedNiveau == null
                      ? 'Choisissez d\'abord un niveau'
                      : 'Choisir la filière',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: _selectedNiveau == null ? Colors.grey.shade100 : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
                items: AppConstants.getFilieresByNiveau(_selectedNiveau).map((f) =>
                    DropdownMenuItem(value: f,
                        child: Text(f, style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _selectedNiveau == null ? null : (v) =>
                    setState(() => _selectedFiliere = v),
                validator: (v) => v == null ? 'Filière requise' : null,
              ),
              const SizedBox(height: 20),

              // ── Matière ──
              _label('Matière *'),
              const SizedBox(height: 8),
              if (isTeacher && user!.matieres.isNotEmpty)
                // Prof : choisit parmi ses matières
                DropdownButtonFormField<String>(
                  value: _selectedMatiere,
                  isExpanded: true,
                  decoration: _inputDeco('Choisir la matière'),
                  items: user.matieres.map((m) =>
                      DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _selectedMatiere = v),
                  validator: (v) => v == null ? 'Matière requise' : null,
                )
              else
                // Admin : toutes les matières
                DropdownButtonFormField<String>(
                  value: _selectedMatiere,
                  isExpanded: true,
                  decoration: _inputDeco('Choisir la matière'),
                  items: AppConstants.matieres.map((m) =>
                      DropdownMenuItem(value: m,
                          child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _selectedMatiere = v),
                  validator: (v) => v == null ? 'Matière requise' : null,
                ),
              const SizedBox(height: 20),

              // ── Salle (optionnel) ──
              _label('Salle (optionnel)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _salleController,
                decoration: _inputDeco('Ex: A1, B2, Amphi...'),
              ),
              const SizedBox(height: 30),

              // ── Bouton enregistrer ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedJour == null || _selectedSlot == null || _isLoading)
                      ? null
                      : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C3A6B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer le cours',
                          style: TextStyle(color: Colors.white, fontSize: 16,
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
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: Color(0xFF1C2A3A)));

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1C3A6B), width: 1.5)),
  );
}