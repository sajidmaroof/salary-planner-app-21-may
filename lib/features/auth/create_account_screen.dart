import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'social_login_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  String? _error;
  bool _success = false;
  String _firstName = '';

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_firstCtrl.text.trim().isEmpty) {
      setState(() => _error = 'First name is required.');
      return;
    }
    if (_lastCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Last name is required.');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Email is required.');
      return;
    }
    if (_pwCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_pwCtrl.text != _pw2Ctrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      await credential.user?.updateDisplayName(
        '${_firstCtrl.text.trim()} ${_lastCtrl.text.trim()}',
      );

      setState(() {
        _firstName = _firstCtrl.text.trim();
        _success = true;
        _isLoading = false;
      });
      // AppAuthNotifier picks up auth state change; router redirects to /setup automatically.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(e.code);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _errorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      default:
        return 'Account creation failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return _SuccessView(
        firstName: _firstName,
        onContinue: () => context.go('/setup'),
      );
    }

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
                'Create Account',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D1B69),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fill in your details to get started.',
                style: TextStyle(color: Color(0xFF7A6E9B), fontSize: 14),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('First Name'),
                        _AppTextField(
                          controller: _firstCtrl,
                          hint: 'Jane',
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Last Name'),
                        _AppTextField(
                          controller: _lastCtrl,
                          hint: 'Doe',
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _FieldLabel('Email'),
              _AppTextField(
                controller: _emailCtrl,
                hint: 'you@example.com',
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),

              _FieldLabel('Create Password'),
              _PasswordField(
                controller: _pwCtrl,
                hint: 'Min. 6 characters',
                showPassword: _showPassword,
                onToggle: () =>
                    setState(() => _showPassword = !_showPassword),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),

              _FieldLabel('Confirm Password'),
              _AppTextField(
                controller: _pw2Ctrl,
                hint: 'Re-enter password',
                obscure: true,
                onChanged: (_) => setState(() => _error = null),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: Color(0xFFE8409C), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFF7B5CFA)),
                      ),
                    )
                  : AuthGradientButton(
                      label: 'Create Account', onTap: _submit),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: Color(0xFF7A6E9B), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/signin'),
                    child: const Text(
                      'Sign in',
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

// ─── Success view ─────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final String firstName;
  final VoidCallback onContinue;
  const _SuccessView({required this.firstName, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B5CFA), Color(0xFFE8409C)],
                  ),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Account Created!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D1B69)),
              ),
              const SizedBox(height: 10),
              Text(
                "Welcome, $firstName! Let's set up your budget.",
                style: const TextStyle(color: Color(0xFF7A6E9B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AuthGradientButton(
                  label: 'Set Up My Budget', onTap: onContinue),
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
  final bool obscure;
  final ValueChanged<String>? onChanged;

  const _AppTextField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
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
  final String hint;

  const _PasswordField({
    required this.controller,
    required this.showPassword,
    required this.onToggle,
    this.onChanged,
    this.hint = '••••••••',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFF2D1B69), fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
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
