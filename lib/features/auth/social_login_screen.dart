import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

// ─── Success screen ───────────────────────────────────────────────────────────
class _SuccessScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onHome;
  const _SuccessScreen(
      {required this.title,
      required this.subtitle,
      required this.onHome});

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
              Text(title,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D1B69))),
              const SizedBox(height: 10),
              Text(subtitle,
                  style: const TextStyle(color: Color(0xFF7A6E9B)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              AuthGradientButton(label: 'Back to Home', onTap: onHome),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Social Login Screen ──────────────────────────────────────────────────────
class SocialLoginScreen extends StatefulWidget {
  final String provider; // 'Google' | 'Facebook' | 'Apple'
  const SocialLoginScreen({Key? key, required this.provider}) : super(key: key);

  @override
  State<SocialLoginScreen> createState() => _SocialLoginScreenState();
}

class _SocialLoginScreenState extends State<SocialLoginScreen> {
  int? _selected;
  bool _success = false;

  static const _accounts = {
    'Facebook': [
      {'name': 'Jane Doe', 'email': 'jane.doe@facebook.com', 'initials': 'JD'},
      {'name': 'John Smith', 'email': 'john.smith@facebook.com', 'initials': 'JS'},
    ],
    'Google': [
      {'name': 'jane.doe@gmail.com', 'email': 'jane.doe@gmail.com', 'initials': 'J'},
      {'name': 'work@company.com', 'email': 'work@company.com', 'initials': 'W'},
    ],
    'Apple': [
      {'name': 'Jane Doe', 'email': 'jane@icloud.com', 'initials': 'JD'},
      {'name': 'Hide My Email', 'email': 'abc123@privaterelay.appleid.com', 'initials': '?'},
    ],
  };

  static const _colors = {
    'Facebook': Color(0xFF1877F2),
    'Google': Color(0xFFEA4335),
    'Apple': Color(0xFF111111),
  };

  // Text labels instead of icons — render reliably on all platforms
  static const _labels = {
    'Facebook': 'f',
    'Google': 'G',
    'Apple': '',
  };

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final accounts = _accounts[provider] ?? [];
    final color = _colors[provider] ?? const Color(0xFF7B5CFA);
    final label = _labels[provider] ?? provider[0];

    if (_success) {
      return _SuccessScreen(
        title: 'Signed In!',
        subtitle:
            'Logged in via $provider as:\n${accounts[_selected!]['email']}',
        onHome: () => context.go('/'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthBackButton(onTap: () => context.go('/')),
              const SizedBox(height: 24),

              // Header
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue with $provider',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D1B69),
                        ),
                      ),
                      const Text(
                        'Choose an account to sign in',
                        style:
                            TextStyle(color: Color(0xFF7A6E9B), fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Account tiles
              ...accounts.asMap().entries.map((entry) {
                final i = entry.key;
                final acc = entry.value;
                final isSelected = _selected == i;
                return GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEDE9FF)
                          : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7B5CFA)
                            : const Color(0xFFE0D9F7),
                        width: isSelected ? 2 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: color,
                          child: Text(
                            acc['initials']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2D1B69),
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                acc['email']!,
                                style: const TextStyle(
                                  color: Color(0xFF7A6E9B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF7B5CFA), size: 22),
                      ],
                    ),
                  ),
                );
              }),

              // Add another account
              Container(
                margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFC4B8F0), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0ECFF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.add, color: Color(0xFF7B5CFA)),
                  ),
                  title: const Text(
                    'Add another account',
                    style: TextStyle(
                      color: Color(0xFF7B5CFA),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  onTap: () {},
                ),
              ),

              // Continue button
              Opacity(
                opacity: _selected == null ? 0.4 : 1.0,
                child: AuthGradientButton(
                  label: 'Continue with $provider',
                  onTap: () {
                    if (_selected != null) {
                      setState(() => _success = true);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
