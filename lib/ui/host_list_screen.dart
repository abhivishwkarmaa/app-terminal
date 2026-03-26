import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/host_model.dart';
import '../providers/auth_provider.dart';
import '../providers/host_provider.dart';
import 'add_edit_host_screen.dart';
import 'add_edit_mysql_screen.dart';
import 'mysql_workbench_screen.dart';
import 'profile_screen.dart';
import 'terminal_screen.dart';
import 'widgets/reveal_on_mount.dart';
import 'widgets/skeleton.dart';

enum _WorkspaceSection { ssh, mysql }

class HostListScreen extends StatefulWidget {
  const HostListScreen({super.key});

  @override
  State<HostListScreen> createState() => _HostListScreenState();
}

class _HostListScreenState extends State<HostListScreen> {
  _WorkspaceSection _section = _WorkspaceSection.ssh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Workspace',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Consumer<AuthProvider>(
            builder: (context, auth, child) {
              return IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: theme.cardColor.withValues(alpha: 0.78),
                  side: BorderSide(color: primary.withValues(alpha: 0.12)),
                ),
                icon: CircleAvatar(
                  radius: 15,
                  backgroundColor: primary.withValues(alpha: 0.18),
                  backgroundImage: auth.user?.pictureUrl != null
                      ? NetworkImage(auth.user!.pictureUrl!)
                      : null,
                  child: auth.user?.pictureUrl == null
                      ? Icon(Icons.person, size: 18, color: primary)
                      : null,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          Consumer<HostProvider>(
            builder: (context, hostProvider, child) {
              return IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: theme.cardColor.withValues(alpha: 0.78),
                  side: BorderSide(color: primary.withValues(alpha: 0.12)),
                ),
                icon: const Icon(Icons.search_rounded),
                onPressed: () {
                  final scopedHosts = hostProvider.hosts
                      .where(
                        (host) => _section == _WorkspaceSection.ssh
                            ? host.connectionType == ConnectionType.ssh
                            : host.connectionType == ConnectionType.mysql,
                      )
                      .toList();
                  if (_section == _WorkspaceSection.ssh) {
                    showSearch(
                      context: context,
                      delegate: HostSearchDelegate(
                        scopedHosts,
                        hostProvider,
                        false,
                      ),
                    );
                    return;
                  }
                  showSearch(
                    context: context,
                    delegate: HostSearchDelegate(
                      scopedHosts,
                      hostProvider,
                      true,
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 16),
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
              top: -110,
              right: -30,
              child: _GlowAccent(
                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                size: 260,
              ),
            ),
            Positioned(
              top: 130,
              left: -80,
              child: _GlowAccent(
                color: primary.withValues(alpha: 0.14),
                size: 220,
              ),
            ),
            SafeArea(
              child: Consumer2<HostProvider, AuthProvider>(
                builder: (context, hostProvider, authProvider, child) {
                  if (hostProvider.isLoading) {
                    return const _HostListSkeleton();
                  }

                  final sshHosts = hostProvider.hosts
                      .where(
                        (host) => host.connectionType == ConnectionType.ssh,
                      )
                      .toList();
                  final mysqlConnections = hostProvider.hosts
                      .where(
                        (host) => host.connectionType == ConnectionType.mysql,
                      )
                      .toList();

                  return RefreshIndicator(
                    onRefresh: hostProvider.loadHosts,
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                      children: [
                        RevealOnMount(
                          child: _WorkspaceHero(
                            userName: authProvider.user?.name ?? 'Operator',
                            sshCount: sshHosts.length,
                            mysqlCount: mysqlConnections.length,
                            pendingSyncCount: hostProvider.pendingSyncCount,
                            section: _section,
                          ),
                        ),
                        const SizedBox(height: 18),
                        RevealOnMount(
                          delay: const Duration(milliseconds: 100),
                          child: _WorkspaceSectionSwitch(
                            selected: _section,
                            onSelected: (section) {
                              setState(() {
                                _section = section;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_section == _WorkspaceSection.ssh) ...[
                          RevealOnMount(
                            delay: const Duration(milliseconds: 120),
                            child: _SectionLabel(
                              title: 'SSH HOSTS',
                              trailing: '${sshHosts.length} configured',
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (sshHosts.isEmpty)
                            RevealOnMount(
                              delay: const Duration(milliseconds: 220),
                              child: _EmptyState(
                                icon: Icons.dns_rounded,
                                title: 'No SSH hosts configured yet',
                                description:
                                    'Add your first environment to start opening remote terminal sessions from one clean workspace.',
                                buttonLabel: 'Create SSH Host',
                                onCreate: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AddEditHostScreen(),
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            ...List.generate(sshHosts.length, (index) {
                              final host = sshHosts[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: RevealOnMount(
                                  delay: Duration(
                                    milliseconds: 180 + (index * 70),
                                  ),
                                  child: _HostCard(
                                    host: host,
                                    hostProvider: hostProvider,
                                    isPendingSync: hostProvider.isPendingSync(
                                      host.id,
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ] else ...[
                          RevealOnMount(
                            delay: const Duration(milliseconds: 120),
                            child: _SectionLabel(
                              title: 'MYSQL CONNECTIONS',
                              trailing: '${mysqlConnections.length} configured',
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (mysqlConnections.isEmpty)
                            RevealOnMount(
                              delay: const Duration(milliseconds: 220),
                              child: _EmptyState(
                                icon: Icons.storage_rounded,
                                title: 'No MySQL connections yet',
                                description:
                                    'Save a MySQL host to open a mobile workbench with database selection, query runner, and result export.',
                                buttonLabel: 'Create MySQL Connection',
                                onCreate: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AddEditMySqlScreen(),
                                    ),
                                  );
                                },
                              ),
                            )
                          else ...[
                            ...List.generate(mysqlConnections.length, (index) {
                              final connection = mysqlConnections[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: RevealOnMount(
                                  delay: Duration(
                                    milliseconds: 180 + (index * 70),
                                  ),
                                  child: _MySqlConnectionCard(
                                    connection: connection,
                                    hostProvider: hostProvider,
                                    isPendingSync: hostProvider.isPendingSync(
                                      connection.id,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_section == _WorkspaceSection.ssh) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddEditHostScreen(),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditMySqlScreen()),
          );
        },
        icon: Icon(
          _section == _WorkspaceSection.ssh
              ? Icons.add_rounded
              : Icons.storage_rounded,
        ),
        label: Text(
          _section == _WorkspaceSection.ssh ? 'Add Host' : 'Add MySQL',
        ),
      ),
    );
  }
}

class _HostListSkeleton extends StatelessWidget {
  const _HostListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: [
        SkeletonCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(width: 148, height: 28),
              SizedBox(height: 14),
              SkeletonBox(height: 14),
              SizedBox(height: 10),
              SkeletonBox(width: 240, height: 14),
              SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: 88)),
                  SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 88)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SkeletonBox(width: 180, height: 54),
        const SizedBox(height: 20),
        const SkeletonBox(width: 140, height: 12),
        const SizedBox(height: 16),
        for (int i = 0; i < 4; i++) ...[
          SkeletonCard(
            child: Row(
              children: const [
                SkeletonBox(
                  width: 58,
                  height: 58,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 18),
                      SizedBox(height: 10),
                      SkeletonBox(height: 14),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SkeletonBox(
                            width: 52,
                            height: 26,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          SkeletonBox(
                            width: 84,
                            height: 26,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          SkeletonBox(
                            width: 74,
                            height: 26,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  final String userName;
  final int sshCount;
  final int mysqlCount;
  final int pendingSyncCount;
  final _WorkspaceSection section;

  const _WorkspaceHero({
    required this.userName,
    required this.sshCount,
    required this.mysqlCount,
    required this.pendingSyncCount,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    final title = section == _WorkspaceSection.ssh
        ? 'Remote access at a glance'
        : 'Database control from your phone';
    final description = section == _WorkspaceSection.ssh
        ? 'Launch remote sessions, audit saved infrastructure, and keep terminal access organized in one place.'
        : 'Browse saved database connections, jump into query tools, and keep essential MySQL actions close at hand.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cardColor.withValues(alpha: 0.95),
            theme.cardColor.withValues(alpha: 0.82),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              section == _WorkspaceSection.ssh
                  ? 'SSH WORKSPACE'
                  : 'MYSQL WORKBENCH',
              style: theme.textTheme.labelMedium?.copyWith(color: primary),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Welcome back, $userName',
                  style: theme.textTheme.headlineMedium?.copyWith(height: 1),
                ),
              ),
              _SyncIndicator(pendingCount: pendingSyncCount),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'SSH hosts',
                  value: sshCount.toString().padLeft(2, '0'),
                  accent: primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'MySQL',
                  value: mysqlCount.toString().padLeft(2, '0'),
                  accent: secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSectionSwitch extends StatelessWidget {
  final _WorkspaceSection selected;
  final ValueChanged<_WorkspaceSection> onSelected;

  const _WorkspaceSectionSwitch({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'SSH',
              icon: Icons.terminal_rounded,
              selected: selected == _WorkspaceSection.ssh,
              onTap: () => onSelected(_WorkspaceSection.ssh),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SegmentButton(
              label: 'MySQL',
              icon: Icons.storage_rounded,
              selected: selected == _WorkspaceSection.mysql,
              onTap: () => onSelected(_WorkspaceSection.mysql),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? primary.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected
                    ? primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionLabel({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(title, style: theme.textTheme.labelMedium),
        const Spacer(),
        Text(
          trailing,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onCreate;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 40, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 18),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(onPressed: onCreate, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class HostSearchDelegate extends SearchDelegate {
  final List<HostModel> hosts;
  final HostProvider hostProvider;
  final bool showMySql;

  HostSearchDelegate(this.hosts, this.hostProvider, this.showMySql);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    final results = hosts.where((h) {
      return h.displayName.toLowerCase().contains(query.toLowerCase()) ||
          h.host.toLowerCase().contains(query.toLowerCase()) ||
          h.username.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Text(
          'No environments matched "$query".',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final host = results[index];
        if (showMySql) {
          return _MySqlConnectionCard(
            connection: host,
            hostProvider: hostProvider,
            isPendingSync: hostProvider.isPendingSync(host.id),
          );
        }
        return _HostCard(
          host: host,
          hostProvider: hostProvider,
          isPendingSync: hostProvider.isPendingSync(host.id),
        );
      },
    );
  }
}

class _HostCard extends StatelessWidget {
  final HostModel host;
  final HostProvider hostProvider;
  final bool isPendingSync;

  const _HostCard({
    required this.host,
    required this.hostProvider,
    required this.isPendingSync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(minHeight: 188),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.cardColor.withValues(alpha: 0.88),
        border: Border.all(color: primary.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TerminalScreen(host: host)),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.18),
                      theme.colorScheme.secondary.withValues(alpha: 0.14),
                    ],
                  ),
                ),
                child: Icon(Icons.terminal_rounded, color: primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(host.displayName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '${host.username}@${host.host}:${host.port}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _Tag(text: 'SSH', color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          _Tag(
                            text: isPendingSync ? 'Pending sync' : 'Synced',
                            color: isPendingSync ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _Tag(
                            text: host.authType.label,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          _Tag(
                            text: 'Port ${host.port}',
                            color: theme.colorScheme.secondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEditHostScreen(host: host),
                      ),
                    );
                  } else if (value == 'delete') {
                    _confirmDelete(context, hostProvider, host);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    HostProvider provider,
    HostModel host,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Host'),
        content: Text('Are you sure you want to delete "${host.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteHost(host.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Host "${host.displayName}" deleted successfully!',
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MySqlConnectionCard extends StatelessWidget {
  final HostModel connection;
  final HostProvider hostProvider;
  final bool isPendingSync;

  const _MySqlConnectionCard({
    required this.connection,
    required this.hostProvider,
    required this.isPendingSync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      constraints: const BoxConstraints(minHeight: 188),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.cardColor.withValues(alpha: 0.88),
        border: Border.all(color: primary.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MySqlWorkbenchScreen(connection: connection),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.secondary.withValues(alpha: 0.18),
                      theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.storage_rounded,
                  color: theme.colorScheme.secondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.displayName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${connection.username}@${connection.host}:${connection.port}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _Tag(
                            text: 'MySQL',
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          _Tag(
                            text: isPendingSync ? 'Pending sync' : 'Synced',
                            color: isPendingSync ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _Tag(
                            text: connection.authType.label,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          _Tag(
                            text: 'Port ${connection.port}',
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddEditMySqlScreen(connection: connection),
                      ),
                    );
                  } else if (value == 'delete') {
                    _confirmDelete(context, hostProvider, connection);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    HostProvider provider,
    HostModel connection,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete MySQL Connection'),
        content: Text(
          'Are you sure you want to delete "${connection.displayName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteHost(connection.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'MySQL connection "${connection.displayName}" deleted successfully!',
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  final int pendingCount;

  const _SyncIndicator({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPending = pendingCount > 0;
    final color = hasPending ? Colors.orange : Colors.green;
    final label = hasPending ? '$pendingCount pending sync' : 'All synced';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
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
