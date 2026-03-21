import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_mode_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/host_provider.dart';
import 'providers/theme_provider.dart';
import 'services/ssh_service.dart';
import 'ui/host_list_screen.dart';
import 'ui/offline_screen.dart';
import 'ui/login_screen.dart';
import 'ui/widgets/skeleton.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider2<
          AuthProvider,
          AppModeProvider,
          HostProvider
        >(
          create: (_) => HostProvider(),
          update: (_, auth, appMode, host) =>
              (host ?? HostProvider())..updateDependencies(auth, appMode),
        ),
        ChangeNotifierProvider(create: (_) => SSHService()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const TermSSHApp(),
    ),
  );
}

class TermSSHApp extends StatelessWidget {
  const TermSSHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, AuthProvider, AppModeProvider>(
      builder: (context, themeProvider, authProvider, appModeProvider, child) {
        // Return MaterialApp FIRST to ensure we have a valid context/theme
        return MaterialApp(
          title: 'TermSSH',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.getAppTheme(),
          home: _getHome(appModeProvider, authProvider),
        );
      },
    );
  }

  Widget _getHome(AppModeProvider appMode, AuthProvider auth) {
    if (appMode.isLoading || (appMode.isSyncMode && auth.isAuthLoading)) {
      return const _SplashLoading();
    }

    if (!appMode.hasSelectedMode) {
      return const LoginScreen();
    }

    if (appMode.isOfflineMode) {
      return const HostListScreen();
    }

    if (auth.isAuthenticated) {
      return Consumer<ConnectivityProvider>(
        builder: (context, connectivity, child) {
          if (connectivity.isOffline) return const OfflineScreen();
          return const HostListScreen();
        },
      );
    }

    return const LoginScreen();
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
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
            top: -100,
            left: -40,
            child: _GlowOrb(
              color: secondary.withValues(alpha: 0.22),
              size: 240,
            ),
          ),
          Positioned(
            bottom: -120,
            right: -30,
            child: _GlowOrb(color: primary.withValues(alpha: 0.16), size: 260),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.92, end: 1),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: child,
                                );
                              },
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 1400),
                                curve: Curves.easeInOut,
                                builder: (context, value, child) {
                                  return Container(
                                    width: 164,
                                    height: 164,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: primary.withValues(
                                          alpha: 0.14 + (value * 0.1),
                                        ),
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 112,
                                        height: 112,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              primary.withValues(alpha: 0.22),
                                              secondary.withValues(alpha: 0.06),
                                              Colors.transparent,
                                            ],
                                          ),
                                          border: Border.all(
                                            color: primary.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                            child: Image.asset(
                                              'assets/icon.png',
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 28),
                            SkeletonBox(
                              width: 152,
                              height: 18,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            const SizedBox(height: 12),
                            SkeletonBox(
                              width: 230,
                              height: 12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            const SizedBox(height: 10),
                            SkeletonBox(
                              width: 180,
                              height: 12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: 160,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: const LinearProgressIndicator(
                                  minHeight: 4,
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
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

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
