import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  static const Color _purpleLight = Color(0xFFB06EFF);
  static const Color _purpleDark = Color(0xFF6A0DAD);
  static const Color _bgDark = Color(0xFFF1EFF7);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Radial purple glow at top
          Positioned(
            top: -64,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 304,
                height: 304,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _purpleLight.withValues(alpha: 0.55),
                      _purpleDark.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.30),

                    // Gradient stroke circle with wallet icon
                    const _GradientCircleIcon(),

                    const SizedBox(height: 13),

                    // Title
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Master Your\n',
                            style: TextStyle(
                              color: Color(0xFF1E223E),
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: _GradientText(
                              'Daily Spending',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Take total control of your money. Know exactly\nwhat you can afford to spend each day\nuntil payday.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1E223E).withValues(alpha: 0.6),
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Sign In button (gradient stroke border, white fill)
                    _GradientBorderButton(
                      label: 'Sign In',
                      onTap: () => context.push('/signin'),
                    ),

                    const SizedBox(height: 11),

                    // Create Account button (solid purple gradient)
                    _SolidGradientButton(
                      label: 'Create Account',
                      onTap: () => context.push('/signup'),
                    ),

                    const SizedBox(height: 29),

                    // Divider with "or continue with"
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Color(0xFF1E223E).withValues(alpha: 0.15),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              color: Color(0xFF1E223E).withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Color(0xFF1E223E).withValues(alpha: 0.15),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 19),

                    // Social login buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SocialButton(
                          icon: SvgPicture.asset('assets/icons/google_icon.svg', width: 15, height: 15),
                          onTap: () => context.push('/social-login/Google'),
                        ),
                        const SizedBox(width: 13),
                        _SocialButton(
                          icon: SvgPicture.asset('assets/icons/apple_icon.svg', width: 14, height: 14),
                          onTap: () => context.push('/social-login/Apple'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 29),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SVG wallet icon (exact design from Illustrator) ───────────────────────────

class _GradientCircleIcon extends StatelessWidget {
  const _GradientCircleIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/wallet_icon.svg',
      width: 136,
      height: 136,
    );
  }
}

// ── Gradient text ─────────────────────────────────────────────────────────────

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _GradientText(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFB06EFF), Color(0xFF7B2FD4)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

// ── Sign In: gradient stroke border, white fill ───────────────────────────────

class _GradientBorderButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientBorderButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _GradientBorderPainter(radius: 30),
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFE8D5FF),
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: Color(0xFF1E223E),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double radius;
  const _GradientBorderPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF9B5BFF), Color(0xFFD946EF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Create Account: solid purple gradient ─────────────────────────────────────

class _SolidGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SolidGradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B3CF7), Color(0xFFD946EF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Create Account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ── Social button card ────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;

  const _SocialButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _GradientBorderPainter(radius: 8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

