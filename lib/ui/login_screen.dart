import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';
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
  AppMode? _selectedMode;
  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  Future<void> _handleContinue() async {
    if (_selectedMode == null || _isLoading) return;

    setState(() => _isLoading = true);
    final appMode = Provider.of<AppModeProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (_selectedMode == AppMode.offline) {
        await appMode.selectMode(AppMode.offline);
        return;
      }

      final success = await auth.login();
      if (success) {
        await appMode.selectMode(AppMode.sync);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cloud sign-in failed. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RevealOnMount(
                                  child: Text(
                                    'Choose How TermSSH Works',
                                    style: theme.textTheme.displaySmall,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                RevealOnMount(
                                  delay: const Duration(milliseconds: 100),
                                  child: Text(
                                    'Offline mode never talks to your backend. Sync mode stores only host metadata in your backend and keeps passwords and private keys on-device.',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.72),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                RevealOnMount(
                                  delay: const Duration(milliseconds: 180),
                                  child: _ModeCard(
                                    mode: AppMode.offline,
                                    selected: _selectedMode == AppMode.offline,
                                    onTap: _isLoading
                                        ? null
                                        : () => setState(
                                            () =>
                                                _selectedMode = AppMode.offline,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                RevealOnMount(
                                  delay: const Duration(milliseconds: 260),
                                  child: _ModeCard(
                                    mode: AppMode.sync,
                                    selected: _selectedMode == AppMode.sync,
                                    onTap: _isLoading
                                        ? null
                                        : () => setState(
                                            () => _selectedMode = AppMode.sync,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                RevealOnMount(
                                  delay: const Duration(milliseconds: 340),
                                  child: Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor.withValues(
                                        alpha: 0.84,
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: primary.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedMode == AppMode.sync
                                              ? 'Sync mode details'
                                              : 'Offline mode details',
                                          style: theme.textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _selectedMode == AppMode.sync
                                              ? 'Hosts sync with your backend after sign-in. Passwords, private keys, and passphrases never sync.'
                                              : 'Hosts and credentials stay on this device only. No backend login, no host sync, and no cloud dependency.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.68),
                                                height: 1.5,
                                              ),
                                        ),
                                        const SizedBox(height: 18),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _selectedMode == null
                                                ? null
                                                : _handleContinue,
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.4,
                                                        ),
                                                  )
                                                : Text(
                                                    _selectedMode ==
                                                            AppMode.sync
                                                        ? 'Continue With Sync'
                                                        : 'Start Offline',
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

class _ModeCard extends StatelessWidget {
  final AppMode mode;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: selected ? 0.96 : 0.82),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.44)
                  : primary.withValues(alpha: 0.12),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  mode == AppMode.offline
                      ? Icons.phonelink_lock_rounded
                      : Icons.cloud_sync_rounded,
                  color: primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode.label, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      mode.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.34),
              ),
            ],
          ),
        ),
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
