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
    setState(() => _isLoading = true);
    final success =
        await Provider.of<AuthProvider>(context, listen: false).login();
    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login failed. Please try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 640;
                    final compact = constraints.maxWidth < 420;
                    final horizontal = wide ? 48.0 : 24.0;

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RevealOnMount(
                                  beginOffset: const Offset(0, 18),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: primary.withValues(alpha: 0.18),
                                          ),
                                        ),
                                        child: Text(
                                          'SECURE REMOTE WORKSPACE',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),
                                RevealOnMount(
                                  delay: const Duration(milliseconds: 120),
                                  beginOffset: const Offset(0, 24),
                                  child: compact
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _LoginBrandMark(
                                              primary: primary,
                                              secondary: secondary,
                                            ),
                                            const SizedBox(height: 18),
                                            Text(
                                              'TermSSH',
                                              style: theme.textTheme.displayMedium
                                                  ?.copyWith(height: 0.98),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Developer-grade SSH access with cloud sync, encrypted credentials, and a calmer control surface.',
                                              style: theme.textTheme.bodyLarge?.copyWith(
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.72),
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            _LoginBrandMark(
                                              primary: primary,
                                              secondary: secondary,
                                            ),
                                            const SizedBox(width: 18),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'TermSSH',
                                                    style: theme.textTheme.displayMedium
                                                        ?.copyWith(height: 0.98),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Developer-grade SSH access with cloud sync, encrypted credentials, and a calmer control surface.',
                                                    style: theme.textTheme.bodyLarge?.copyWith(
                                                      color: theme.colorScheme.onSurface
                                                          .withValues(alpha: 0.72),
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                  ),
                                const SizedBox(height: 28),
                                RevealOnMount(
                                  delay: const Duration(milliseconds: 220),
                                  child: Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor.withValues(alpha: 0.82),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: primary.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        _MetricRow(
                                          icon: Icons.shield_outlined,
                                          title: 'Encrypted sync',
                                          subtitle:
                                              'Access tokens stay short-lived while credentials remain protected.',
                                        ),
                                        const SizedBox(height: 16),
                                        _MetricRow(
                                          icon: Icons.bolt_rounded,
                                          title: 'Fast launch',
                                          subtitle:
                                              'Open straight into your saved hosts with polished motion and zero clutter.',
                                        ),
                                        const SizedBox(height: 16),
                                        _MetricRow(
                                          icon: Icons.memory_rounded,
                                          title: 'Built for ops',
                                          subtitle:
                                              'A cleaner visual rhythm for server lists, profiles, and terminal work.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                RevealOnMount(
                                  delay: const Duration(milliseconds: 340),
                                  child: Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          theme.cardColor.withValues(alpha: 0.9),
                                          theme.cardColor.withValues(alpha: 0.72),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.06),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Authenticate once',
                                          style: theme.textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Use your Google account to unlock the workspace and keep your terminals in sync across devices.',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.68),
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _isLoading ? null : _handleLogin,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 4,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.g_mobiledata_rounded,
                                                    size: 34,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    _isLoading
                                                        ? 'Connecting...'
                                                        : 'Continue with Google',
                                                  ),
                                                ],
                                              ),
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
                    );
                  },
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

class _LoginBrandMark extends StatelessWidget {
  final Color primary;
  final Color secondary;

  const _LoginBrandMark({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.2),
            secondary.withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(
          color: primary.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.16),
            blurRadius: 30,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/icon.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MetricRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
