import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../core/auth/app_auth_notifier.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Future<LottieComposition?> _compositionFuture;
  late final AnimationController _fadeController;
  bool _navigated = false;
  bool _controllerSetup = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _compositionFuture = _loadComposition();
    Future.delayed(const Duration(seconds: 3), _navigate);
  }

  Future<LottieComposition?> _loadComposition() async {
    try {
      return await AssetLottie('assets/animations/logo_animation.json').load();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    if (appAuthNotifier.isLoading) {
      appAuthNotifier.addListener(_onAuthReady);
    } else {
      _routeBasedOnAuth();
    }
  }

  void _onAuthReady() {
    if (!appAuthNotifier.isLoading) {
      appAuthNotifier.removeListener(_onAuthReady);
      if (mounted) _routeBasedOnAuth();
    }
  }

  void _routeBasedOnAuth() {
    if (!mounted) return;
    if (appAuthNotifier.user == null) {
      context.go('/');
    } else if (!appAuthNotifier.setupComplete) {
      context.go('/setup');
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7B5CFA), Color(0xFF5B3FD9)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeController,
          child: Center(
            child: FutureBuilder<LottieComposition?>(
              future: _compositionFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final composition = snapshot.data!;
                  if (!_controllerSetup) {
                    _controllerSetup = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _controller.duration = composition.duration;
                      _controller.forward().whenComplete(_navigate);
                    });
                  }
                  return Lottie(
                    composition: composition,
                    controller: _controller,
                    width: MediaQuery.of(context).size.width * 0.8,
                    fit: BoxFit.contain,
                  );
                }

                // Fallback branded splash
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Salary Planner',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Smart budgeting, made simple',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
