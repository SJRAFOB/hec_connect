import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'teacher_register_screen.dart';
import 'admin_register_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C3A6B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 24),
              const Text('Bienvenue sur',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const Text('HEC Connect',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1C3A6B))),
              const SizedBox(height: 8),
              const Text(
                'Toutes les informations académiques\nd\'HEC Abidjan dans une seule application.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const Spacer(flex: 2),

              // SE CONNECTER
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C3A6B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('SE CONNECTER',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Pas encore de compte ?',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),

              // Étudiant + Professeur
              Row(
                children: [
                  Expanded(
                    child: _inscriptionBtn(
                      context,
                      icon: Icons.person_outline,
                      label: 'Étudiant',
                      screen: const RegisterScreen(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _inscriptionBtn(
                      context,
                      icon: Icons.cast_for_education_outlined,
                      label: 'Professeur',
                      screen: const TeacherRegisterScreen(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Administration (pleine largeur)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1C3A6B), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF1C3A6B), size: 20),
                  label: const Text('Administration / Staff',
                      style: TextStyle(color: Color(0xFF1C3A6B), fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const AdminRegisterScreen())),
                ),
              ),

              const Spacer(),
              const Text('HEC Abidjan — Côte d\'Ivoire',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inscriptionBtn(BuildContext ctx, {required IconData icon, required String label, required Widget screen}) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF1C3A6B)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, color: const Color(0xFF1C3A6B), size: 20),
      label: Text(label, style: const TextStyle(color: Color(0xFF1C3A6B), fontWeight: FontWeight.bold)),
      onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen)),
    );
  }
}
