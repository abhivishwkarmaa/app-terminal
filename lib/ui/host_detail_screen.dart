import 'package:flutter/material.dart';

import '../models/host_model.dart';
import 'add_edit_host_screen.dart';
import 'terminal_screen.dart';
import 'widgets/reveal_on_mount.dart';

class HostDetailScreen extends StatelessWidget {
  final HostModel host;

  const HostDetailScreen({super.key, required this.host});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Environment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditHostScreen(host: host),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DecoratedBox(
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
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -40,
              child: _GlowAccent(
                color: primary.withValues(alpha: 0.14),
                size: 240,
              ),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  RevealOnMount(child: _Header(host: host)),
                  const SizedBox(height: 18),
                  RevealOnMount(
                    delay: const Duration(milliseconds: 100),
                    child: _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(title: 'CONNECTION'),
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.language_rounded,
                            label: 'Host',
                            value: host.host,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Username',
                            value: host.username,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.numbers_rounded,
                            label: 'Port',
                            value: host.port.toString(),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.verified_user_outlined,
                            label: 'Authentication',
                            value: host.authType.label,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RevealOnMount(
                    delay: const Duration(milliseconds: 180),
                    child: _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SectionLabel(title: 'SECURITY'),
                          SizedBox(height: 14),
                          _SecurityPill(
                            icon: Icons.lock_outline_rounded,
                            title: 'Device-only secrets',
                            subtitle:
                                'Passwords, private keys, and passphrases stay in secure on-device storage only.',
                          ),
                          SizedBox(height: 12),
                          _SecurityPill(
                            icon: Icons.verified_user_outlined,
                            title: 'Reinstall behavior',
                            subtitle:
                                'Credentials are stored securely on your device and are not synced. Please re-enter them after reinstall.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  RevealOnMount(
                    delay: const Duration(milliseconds: 240),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TerminalScreen(host: host),
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.terminal_rounded),
                            SizedBox(width: 10),
                            Text('Open Terminal'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final HostModel host;

  const _Header({required this.host});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            theme.cardColor.withValues(alpha: 0.94),
            theme.cardColor.withValues(alpha: 0.82),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withValues(alpha: 0.18),
                  primary.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Icon(Icons.dns_rounded, size: 40, color: primary),
          ),
          const SizedBox(height: 18),
          Text(host.displayName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '${host.username}@${host.host}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.labelMedium);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                  ),
                ),
                const SizedBox(height: 6),
                Text(value, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SecurityPill({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.secondary.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
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
      ),
    );
  }
}

class _GlowAccent extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowAccent({required this.color, required this.size});

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
