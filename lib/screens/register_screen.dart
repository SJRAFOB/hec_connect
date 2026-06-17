import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _matriculeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedNiveau;
  String? _selectedFiliere;
  List<String> _filieresDispo = [];

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _matriculeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onNiveauChanged(String? niveau) {
    setState(() {
      _selectedNiveau = niveau;
      if (AppConstants.isTroncCommun(niveau)) {
        // Tronc commun : pas de filière
        _selectedFiliere = 'Tronc commun';
        _filieresDispo = [];
      } else {
        _selectedFiliere = null;
        _filieresDispo = AppConstants.getFilieresByNiveau(niveau);
      }
    });
  }

  // BottomSheet pour choisir la filière (évite l'overflow)
  void _showFiliereBottomSheet() {
    if (_selectedNiveau == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Poignée
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Choisissez votre filière',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C3A6B),
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _filieresDispo.length,
                    itemBuilder: (context, index) {
                      final f = _filieresDispo[index];
                      final isSelected = f == _selectedFiliere;
                      return ListTile(
                        title: Text(
                          f,
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? const Color(0xFF1C3A6B)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check,
                                color: Color(0xFF1C3A6B))
                            : null,
                        onTap: () {
                          setState(() => _selectedFiliere = f);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    final success = await auth.register(
      email: _emailController.text,
      password: _passwordController.text,
      nom: _nomController.text,
      prenom: _prenomController.text,
      matricule: _matriculeController.text,
      filiere: _selectedFiliere,
      niveau: _selectedNiveau,
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
                const Text(
                  'Inscription',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Créez votre compte étudiant',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // ── Prénom + Nom ──
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prenomController,
                        textInputAction: TextInputAction.next,
                        decoration:
                            const InputDecoration(labelText: 'Prénom'),
                        validator: (v) =>
                            Validators.notEmpty(v, fieldName: 'Prénom'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _nomController,
                        textInputAction: TextInputAction.next,
                        decoration:
                            const InputDecoration(labelText: 'Nom'),
                        validator: (v) =>
                            Validators.notEmpty(v, fieldName: 'Nom'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Matricule ──
                TextFormField(
                  controller: _matriculeController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Matricule',
                    hintText: 'Ex: HEC16-23-000086',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: Validators.matricule,
                ),
                const SizedBox(height: 14),

                // ── Niveau (dropdown normal) ──
                DropdownButtonFormField<String>(
                  value: _selectedNiveau,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Niveau',
                    prefixIcon: Icon(Icons.bar_chart),
                  ),
                  items: AppConstants.niveaux
                      .map((n) =>
                          DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: _onNiveauChanged,
                  validator: (v) =>
                      v == null ? 'Veuillez choisir un niveau' : null,
                ),
                const SizedBox(height: 14),

                // ── Filière (bouton → BottomSheet) ──
                FormField<String>(
                  validator: (_) => _selectedFiliere == null
                      ? 'Veuillez choisir une filière'
                      : null,
                  builder: (field) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: (_selectedNiveau != null && !AppConstants.isTroncCommun(_selectedNiveau))
                              ? _showFiliereBottomSheet
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              color: _selectedNiveau == null
                                  ? Colors.grey.shade100
                                  : Colors.white,
                              border: Border.all(
                                color: field.hasError
                                    ? Colors.red
                                    : _selectedFiliere != null
                                        ? const Color(0xFF1C3A6B)
                                        : Colors.grey.shade400,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  color: _selectedNiveau == null
                                      ? Colors.grey
                                      : const Color(0xFF1C3A6B),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AppConstants.isTroncCommun(_selectedNiveau)
                                        ? 'Tronc commun'
                                        : (_selectedFiliere ??
                                            (_selectedNiveau == null
                                                ? 'Choisissez d\'abord un niveau'
                                                : 'Choisissez votre filière')),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppConstants.isTroncCommun(_selectedNiveau) || _selectedFiliere != null
                                          ? Colors.black87
                                          : Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: _selectedNiveau == null
                                      ? Colors.grey
                                      : const Color(0xFF1C3A6B),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 12),
                            child: Text(
                              field.errorText!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ── Email ──
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),

                // ── Mot de passe ──
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),

                // ── Confirmer mot de passe ──
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) => Validators.confirmPassword(
                      v, _passwordController.text),
                ),
                const SizedBox(height: 24),

                // ── Bouton S'inscrire ──
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _register,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('S\'INSCRIRE'),
                ),
                const SizedBox(height: 16),

                // ── Déjà un compte ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Déjà un compte ? ',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Se connecter',
                          style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}