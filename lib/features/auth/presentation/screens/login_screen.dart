import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:student_companion/features/auth/domain/models/auth_failure.dart';
import 'package:student_companion/features/auth/presentation/providers/auth_provider.dart';
import 'package:student_companion/shared/widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFCF6679)),
              const SizedBox(width: 10),
              Expanded(child: Text(auth.errorMessage ?? 'Erreur inconnue')),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header ---
                  _GradientIcon(icon: Icons.school_rounded),
                  const SizedBox(height: 28),
                  Text(
                    'Bon retour ! 👋',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous pour continuer.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9E9EBF),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- Form ---
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Veuillez entrer votre email.';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                              return 'Format d\'email invalide.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Veuillez entrer votre mot de passe.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        PrimaryButton(
                          label: 'Se connecter',
                          onPressed: _submit,
                          isLoading: isLoading,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Footer ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Pas encore de compte ? ",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9E9EBF),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Créer un compte'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient icon used as the app logo mark on auth screens.
class _GradientIcon extends StatelessWidget {
  final IconData icon;
  const _GradientIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF03DAC6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}
