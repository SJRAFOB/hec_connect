import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/code_validation_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'portail_choice_screen.dart';

class TeacherRegisterScreen extends StatefulWidget {
  const TeacherRegisterScreen({super.key});
  @override
  State<TeacherRegisterScreen> createState() => _TeacherRegisterScreenState();
}

class _TeacherRegisterScreenState extends State<TeacherRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _secretCodeController = TextEditingController();

  List<String> _selectedMatieres = [];
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _obscureCode = true;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _secretCodeController.dispose();
    super.dispose();
  }

  // Sélecteur multi-matières groupé par domaine
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
                      child: const Text('Effacer', style: TextStyle(color: Colors.red)),
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
                            '${tempSelected.length} matière(s) : ${tempSelected.take(2).join(', ')}${tempSelected.length > 2 ? '...' : ''}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF1C3A6B),
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
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
                            onTap: () => setModal(() {
                              isSel
                                  ? tempSelected.remove(matiere)
                                  : tempSelected.add(matiere);
                            }),
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
                                  color: isSel
                                      ? const Color(0xFF1C3A6B)
                                      : Colors.grey.shade200,
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
                    onPressed: tempSelected.isEmpty ? null : () {
                      setState(() => _selectedMatieres = List.from(tempSelected));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C3A6B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      tempSelected.isEmpty
                          ? 'Sélectionnez au moins une matière'
                          : 'Confirmer (${tempSelected.length})',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMatieres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins une matière')),
      );
      return;
    }

    // Valider le code d'accès côté serveur (le code n'est jamais stocké dans l'app)
    try {
      final valid = await CodeValidationService.validate(
        type: 'teacher',
        code: _secretCodeController.text,
      );
      if (!valid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code d\'accès incorrect'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de vérifier le code. Vérifiez votre connexion.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final auth = context.read<AuthService>();
    final success = await auth.registerTeacher(
      email: _emailController.text,
      password: _passwordController.text,
      nom: _nomController.text,
      prenom: _prenomController.text,
      matieres: _selectedMatieres,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Erreur d\'inscription'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // En-tête cliquable — changer de portail
                GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PortailChoiceScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C3A6B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.cast_for_education_outlined, size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text('Portail Professeur',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 4),
                        Text('HEC Abidjan — Espace enseignant',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                            textAlign: TextAlign.center),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swap_horiz, size: 13, color: Colors.white54),
                            SizedBox(width: 4),
                            Text('Changer de portail',
                                style: TextStyle(fontSize: 11, color: Colors.white54)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Prénom + Nom
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prenomController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                        validator: (v) => Validators.notEmpty(v, fieldName: 'Prénom'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _nomController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        validator: (v) => Validators.notEmpty(v, fieldName: 'Nom'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Matières enseignées (multi-sélection)
                const Text('Matières enseignées *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1C3A6B))),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _showMatieresPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: _selectedMatieres.isEmpty
                            ? Colors.grey.shade400
                            : const Color(0xFF1C3A6B),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_outlined,
                            size: 20, color: Color(0xFF1C3A6B)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _selectedMatieres.isEmpty
                              ? Text('Sélectionner les matières enseignées',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
                              : Wrap(
                                  spacing: 5, runSpacing: 5,
                                  children: _selectedMatieres.map((m) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C3A6B).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(m,
                                        style: const TextStyle(fontSize: 11,
                                            color: Color(0xFF1C3A6B),
                                            fontWeight: FontWeight.w600)),
                                  )).toList(),
                                ),
                        ),
                        Icon(Icons.expand_more, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                if (_selectedMatieres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${_selectedMatieres.length} matière(s) sélectionnée(s)',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ),
                const SizedBox(height: 14),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email professionnel',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),

                // Mot de passe
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),

                // Confirmer mot de passe
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) => Validators.confirmPassword(v, _passwordController.text),
                ),
                const SizedBox(height: 14),

                // Code secret
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C3A6B).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1C3A6B).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.vpn_key, size: 16, color: Color(0xFF1C3A6B)),
                          SizedBox(width: 6),
                          Text('Code d\'accès professeur',
                              style: TextStyle(fontSize: 12, color: Color(0xFF1C3A6B),
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _secretCodeController,
                        obscureText: _obscureCode,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _register(),
                        decoration: InputDecoration(
                          hintText: 'Code fourni par l\'administration',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.lock_clock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureCode ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscureCode = !_obscureCode),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Code requis';
                          return null; // Vérification réelle effectuée côté serveur dans _register()
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: auth.isLoading ? null : _register,
                  child: auth.isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('S\'INSCRIRE COMME PROFESSEUR'),
                ),
                const SizedBox(height: 16),

         