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
  late AnimationController _controller;
  LottieComposition? _composition;
  bool _lottieReady = false;
  bool _lottieFailed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _loadAndPlay();
  }

  Future<void> _loadAndPlay() async {
    try {
      final composition =
          await AssetLottie('assets/animations/logo_animation.json').load();
      if (!mounted) return;
      setState(() {
        _composition = composition;
        _lottieReady = true;
      });
      _controller.duration = composition.duration;
      _controller.forward().whenComplete(() {
        if (mounted) _navigate();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _lottieFailed = true);
        Future.delayed(const Duration(seconds: 2), _navigate);
      }
    }
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
  void dispose() {
    _controller.dispose();
    appAuthNotifier.removeListener(_onAuthReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lottieReady && _composition != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Lottie(
          composition: _composition!,
          controller: _controller,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    if (_lottieFailed) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7B5CFA), Color(0xFF5B3FD9)],
            ),
          ),
          child: Center(
            child: Column(
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
            ),
          ),
        ),
      );
    }

    // Still loading — blank white to match Android launch background
    return const Scaffold(backgroundColor: Colors.white);
  }
}
