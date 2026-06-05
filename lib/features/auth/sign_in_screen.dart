import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'social_login_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _idController.text.trim();
    final pw = _pwController.text;

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email.');
      return;
    }
    if (pw.isEmpty || pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );
      // AppAuthNotifier picks up the auth state change and GoRouter redirects automatically.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _errorMessage(e.code);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _forgotPassword() async {
    final emailController =
        TextEditingController(text: _idController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email and we\'ll send you a link to reset your password.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'EMAIL',
                prefixIcon: const Icon(Icons.email_rounded, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, emailController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B5CFA),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Send Link',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email. Check your inbox.'),
          backgroundColor: const Color(0xFF22C55E),
          duration: const Duration(seconds: 5),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(e.code)),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send reset email. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  String _errorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password. Check and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check network and retry.';
      default:
        return 'Sign in failed ($code). Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthBackButton(onTap: () => context.go('/')),
              const SizedBox(height: 24),
              const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Welcome back! Enter your credentials below.',
                style: TextStyle(color: Color(0xFF7A6E9B), fontSize: 14),
              ),
              const SizedBox(height: 32),

              _FieldLabel('Email'),
              _AppTextField(
                controller: _idController,
                hint: 'you@example.com',
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 16),

              _FieldLabel('Password'),
              _PasswordField(
                controller: _pwController,
                showPassword: _showPassword,
                onToggle: () =>
                    setState(() => _showPassword = !_showPassword),
                onChanged: (_) => setState(() => _error = null),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: Color(0xFF7B5CFA),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: Color(0xFFE8409C), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 8),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFF7B5CFA)),
                      ),
                    )
                  : AuthGradientButton(label: 'Sign In', onTap: _submit),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style:
                        TextStyle(color: Color(0xFF7A6E9B), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/signup'),
                    child: const Text(
                      'Create one',
                      style: TextStyle(
                        color: Color(0xFF7B5CFA),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Private field helpers ────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7B5CFA),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _AppTextField({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFF2D1B69), fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0A8D0)),
        filled: true,
        fillColor: const Color(0xFFF8F6FF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFE0D9F7), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFE0D9F7), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF7B5CFA), width: 2),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool showPassword;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.showPassword,
    required this.onToggle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFF2D1B69), fontSize: 15),
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle: const TextStyle(color: Color(0xFFB0A8D0)),
        filled: true,
        fillColor: const Color(0xFFF8F6FF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: TextButton(
          onPressed: onToggle,
          child: Text(
            showPassword ? 'Hide' : 'Show',
            style: const TextStyle(
              color: Color(0xFF7B5CFA),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFE0D9F7), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFE0D9F7), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF7B5CFA), width: 2),
        ),
      ),
    );
  }
}
