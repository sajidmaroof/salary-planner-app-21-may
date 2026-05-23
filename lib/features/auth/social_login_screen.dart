import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/social_auth_service.dart';

// ─── Shared back button ───────────────────────────────────────────────────────
class AuthBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const AuthBackButton({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF7B5CFA), size: 18),
          SizedBox(width: 6),
          Text(
            'Back',
            style: TextStyle(
              color: Color(0xFF7B5CFA),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gradient button ─────────────────────────────────────────────────────────
class AuthGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AuthGradientButton(
      {Key? key, required this.label, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B5CFA), Color(0xFFE8409C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ─── Social Login Screen ──────────────────────────────────────────────────────
class SocialLoginScreen extends StatefulWidget {
  final String provider;
  const SocialLoginScreen({Key? key, required this.provider}) : super(key: key);

  @override
  State<SocialLoginScreen> createState() => _SocialLoginScreenState();
}

class _SocialLoginScreenState extends State<SocialLoginScreen> {
  bool _loading = true;
  String? _error;

  static const _providerIcons = {
    'Google': 'assets/icons/google_icon.svg',
    'Facebook': 'assets/icons/facebook_icon.svg',
    'Apple': 'assets/icons/apple_icon.svg',
  };

  static const _providerColors = {
    'Google': Color(0xFFEA4335),
    'Facebook': Color(0xFF1877F2),
    'Apple': Color(0xFF000000),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _signIn());
  }

  Future<void> _signIn() async {
    try {
      switch (widget.provider) {
        case 'Google':
          await SocialAuthService.signInWithGoogle();
          break;
        case 'Facebook':
          await SocialAuthService.signInWithFacebook();
          break;
        case 'Apple':
          await SocialAuthService.signInWithApple();
          break;
      }
      // Firebase auth state change handles routing automatically
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final iconPath = _providerIcons[provider];
    final color = _providerColors[provider] ?? const Color(0xFF7B5CFA);

    return Scaffold(
      backgroundColor: const Color(0xFFF1EFF7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthBackButton(onTap: () => context.pop()),
              const Spacer(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: iconPath != null
                            ? SvgPicture.asset(iconPath, width: 40, height: 40)
                            : Icon(Icons.login, color: color, size: 40),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _loading
                          ? 'Signing in with $provider...'
                          : _error != null
                              ? 'Sign-in failed'
                              : 'Continue with $provider',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E223E),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_loading)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(
                          color: color,
                          strokeWidth: 2.5,
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFEA4335),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthGradientButton(
                        label: 'Try Again',
                        onTap: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _signIn();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
