import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:student_companion/features/auth/presentation/providers/auth_provider.dart';
import 'package:student_companion/shared/widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
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
                  // --- Back button ---
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => context.go('/login'),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // --- Header ---
                  Text(
                    'Créer un compte 🚀',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rejoignez Student Companion dès aujourd\'hui.',
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
                              return 'Veuillez entrer un mot de passe.';
                            }
                            if (v.length < 6) {
                              return 'Le mot de passe doit contenir au moins 6 caractères.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirmer le mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'Les mots de passe ne correspondent pas.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        PrimaryButton(
                          label: 'Créer mon compte',
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
                        "Déjà un compte ? ",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9E9EBF),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Se connecter'),
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
