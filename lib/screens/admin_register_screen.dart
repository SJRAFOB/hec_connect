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

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _secretCodeController = TextEditingController();

  String? _selectedPoste;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _obscureCode = true;

  @override
  void initState() {
    super.initState();
    // Réveille le serveur Render dès l'ouverture de l'écran (plan gratuit)
    CodeValidationService.warmup();
  }

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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Valider le code d'accès côté serveur
    try {
      final valid = await CodeValidationService.validate(
        type: _selectedPoste!,
        code: _secretCodeController.text,
      );
      if (!valid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code d\'accès incorrect pour ce poste'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.contains('Trop de tentatives')
          ? 'Trop de tentatives. Attendez 15 minutes et réessayez.'
          : 'Erreur: ${raw.length > 120 ? raw.substring(0, 120) : raw}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    final auth = context.read<AuthService>();
    final success = await auth.registerAdmin(
      email: _emailController.text,
      password: _passwordController.text,
      nom: _nomController.text,
      prenom: _prenomController.text,
      poste: _selectedPoste!,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Erreur d\'inscription'),
          backgroundColor: AppColors.error,
        ),
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
                      color: const Color(0xFFB12831),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text('Portail Administration',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 4),
                        Text('HEC Abidjan — Accès réservé au personnel',
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

                // Poste
                DropdownButtonFormField<String>(
                  initialValue: _selectedPoste,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Poste',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  items: AppConstants.tousLesPostes
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Row(
                              children: [
                                Icon(
                                  p == 'Fondateur' ? Icons.star_outline
                                      : p == 'Directeur' ? Icons.business_center_outlined
                                      : p == 'Comptable' ? Icons.calculate_outlined
                                      : p == 'Éducateur' ? Icons.school_outlined
                                      : Icons.people_outline,
                                  size: 18,
                                  color: const Color(0xFF1C3A6B),
                                ),
                                const SizedBox(width: 8),
                                Text(p),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedPoste = v;
                    _secretCodeController.clear();
                  }),
                  validator: (v) => v == null ? 'Veuillez choisir votre poste' : null,
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

                // Code secret selon le poste
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
                      Row(
                        children: [
                          const Icon(Icons.vpn_key, size: 16, color: Color(0xFF1C3A6B)),
                          const SizedBox(width: 6),
                          Text(
                            _selectedPoste != null
                                ? 'Code d\'accès — $_selectedPoste'
                                : 'Code d\'accès',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF1C3A6B), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _secretCodeController,
                        obscureText: _obscureCode,
                        enabled: _selectedPoste != null,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _register(),
                        decoration: InputDecoration(
                          hintText: _selectedPoste == null
                              ? 'Choisissez d\'abord votre poste'
                              : 'Code fourni par le fondateur',
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

                // Bouton
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C3A6B)),
                  child: auth.isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('CRÉER MON COMPTE'),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Déjà un compte ? ',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const Login