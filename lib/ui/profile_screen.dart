import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/host_provider.dart';
import '../providers/theme_provider.dart';
import 'host_detail_screen.dart';
import 'widgets/reveal_on_mount.dart';
import 'widgets/skeleton.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.redAccent : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        final user = Provider.of<AuthProvider>(context, listen: false).user;
        _nameController.text = user?.name ?? '';
      }
    });
  }

  Future<void> _saveName() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    final success = await auth.updateProfile(newName);
    if (success) {
      if (mounted) {
        setState(() => _isEditing = false);
        _showFeedback('Profile updated successfully!');
      }
    } else {
      _showFeedback('Failed to update profile.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const _ProfileSkeletonScreen();
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 80,
            floating: false,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Account Settings', 
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  RevealOnMount(
                    child: _buildProfileHeader(user),
                  ),
                  const SizedBox(height: 32),
                  RevealOnMount(
                    delay: const Duration(milliseconds: 120),
                    child: _buildThemeSection(themeProvider),
                  ),
                  const SizedBox(height: 32),
                  RevealOnMount(
                    delay: const Duration(milliseconds: 220),
                    child: _buildSectionTitle('CONNECTED CLOUD SYSTEMS'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          Consumer<HostProvider>(
            builder: (context, hostProvider, child) {
              if (hostProvider.hosts.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text('No terminals linked yet.', 
                        style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final host = hostProvider.hosts[index];
                      return RevealOnMount(
                        delay: Duration(milliseconds: 260 + (index * 60)),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => HostDetailScreen(host: host)),
                              );
                            },
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.dns_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(host.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(host.host, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                    childCount: hostProvider.hosts.length,
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 32),
                  Material(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () {
                        auth.logout();
                        Navigator.pop(context);
                        _showFeedback('Session ended');
                      },
                      borderRadius: BorderRadius.circular(14),
                    child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'LOGOUT ACCOUNT',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('TermSSH Sync v1.0.0', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BackendUser user) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), width: 1.5),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                backgroundImage: user.pictureUrl != null ? NetworkImage(user.pictureUrl!) : null,
                child: user.pictureUrl == null 
                  ? Icon(Icons.person_rounded, size: 60, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8))
                  : null,
              ),
            ),
            GestureDetector(
              onTap: _toggleEdit,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
                child: Icon(
                  _isEditing ? Icons.check_rounded : Icons.edit_rounded, 
                  color: Colors.white, 
                  size: 16
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isEditing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                hintText: 'Your name',
                counterText: '',
                contentPadding: EdgeInsets.zero,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
              onSubmitted: (_) => _saveName(),
              autofocus: true,
              maxLength: 25,
            ),
          )
        else
          Text(user.name, 
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(user.email, style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildThemeSection(ThemeProvider tp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SYSTEM APPEARANCE'),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _themeCard(tp, 'Light', Icons.wb_sunny_rounded, Colors.orange),
              _themeCard(tp, 'Dark', Icons.nights_stay_rounded, Colors.indigo),
              _themeCard(tp, 'Matrix', Icons.terminal_rounded, Colors.green),
              _themeCard(tp, 'Ubuntu', Icons.computer_rounded, Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  Widget _themeCard(ThemeProvider tp, String name, IconData icon, Color color) {
    final isSelected = tp.currentTheme == name;
    return GestureDetector(
      onTap: () {
        tp.setTheme(name);
        _showFeedback('Theme switched to $name');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 85,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[400], size: 24),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(thickness: 1, color: Colors.grey.withValues(alpha: 0.1))),
      ],
    );
  }
}

class _ProfileSkeletonScreen extends StatelessWidget {
  const _ProfileSkeletonScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverAppBar(
            expandedHeight: 80,
            floating: false,
            pinned: true,
            elevation: 0,
            title: Text('Account Settings'),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  const SkeletonBox(
                    width: 104,
                    height: 104,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  const SizedBox(height: 18),
                  const SkeletonBox(width: 180, height: 22),
                  const SizedBox(height: 10),
                  const SkeletonBox(width: 240, height: 14),
                  const SizedBox(height: 34),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: SkeletonBox(width: 170, height: 12),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => const SkeletonBox(
                        width: 86,
                        height: 100,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: SkeletonBox(width: 190, height: 12),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SkeletonCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: const [
                        SkeletonBox(
                          width: 40,
                          height: 40,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 130, height: 16),
                              SizedBox(height: 8),
                              SkeletonBox(width: 200, height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                childCount: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
