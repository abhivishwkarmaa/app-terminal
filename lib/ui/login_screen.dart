import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'widgets/reveal_on_mount.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final success = await Provider.of<AuthProvider>(
      context,
      listen: false,
    ).login();
    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login failed. Please try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final pulse = 0.85 + (_glowController.value * 0.25);
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.scaffoldBackgroundColor,
                      theme.colorScheme.surface,
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -80,
                right: -30,
                child: _AmbientOrb(
                  color: secondary.withValues(alpha: 0.15 * pulse),
                  size: 240,
                ),
              ),
              Positioned(
                bottom: -60,
                left: -20,
                child: _AmbientOrb(
                  color: primary.withValues(alpha: 0.18 * pulse),
                  size: 280,
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RevealOnMount(
                            child: Text(
                              'TermSSH',
                              style: theme.textTheme.displaySmall,
                            ),
                          ),
                          const SizedBox(height: 10),
                          RevealOnMount(
                            delay: const Duration(milliseconds: 100),
                            child: Text(
                              'Sign in to sync host metadata with your backend. Passwords and private keys still stay only on-device.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.72,
                                ),
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          RevealOnMount(
                            delay: const Duration(milliseconds: 180),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: theme.cardColor.withValues(alpha: 0.84),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Device-safe sync',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Hosts sync across devices through your backend, but private keys, passwords, and passphrases are never uploaded.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.68),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _handleLogin,
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                              ),
                                            )
                                          : const Icon(Icons.login_rounded),
                                      label: Text(
                                        _isLoading
                                            ? 'Signing in...'
                                            : 'Continue With Google',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size / 2,
              spreadRadius: size / 8,
            ),
          ],
        ),
      ),
    );
  }
}
