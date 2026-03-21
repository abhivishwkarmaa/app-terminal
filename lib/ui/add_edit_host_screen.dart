import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/host_model.dart';
import '../providers/host_provider.dart';
import '../services/ssh_service.dart';
import 'widgets/reveal_on_mount.dart';
import 'widgets/skeleton.dart';

class AddEditHostScreen extends StatefulWidget {
  final HostModel? host;

  const AddEditHostScreen({super.key, this.host});

  @override
  State<AddEditHostScreen> createState() => _AddEditHostScreenState();
}

class _AddEditHostScreenState extends State<AddEditHostScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  bool _isSaving = false;

  bool get _isEditing => widget.host != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.host?.name ?? '');
    _hostController = TextEditingController(text: widget.host?.host ?? '');
    _portController =
        TextEditingController(text: widget.host?.port.toString() ?? '22');
    _usernameController =
        TextEditingController(text: widget.host?.username ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = Provider.of<HostProvider>(context, listen: false);
    final sshService = Provider.of<SSHService>(context, listen: false);

    final name = _nameController.text.trim();
    final hostAddr = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? 22;
    final username = _usernameController.text.trim();
    String password = _passwordController.text;

    try {
      if (_isEditing && password.isEmpty) {
        final existingPass = await provider.getPassword(widget.host!.id);
        password = existingPass ?? '';
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Verifying updated connection...'
                    : 'Validating new environment...',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
      }

      final isValid = await sshService.testConnection(
        host: hostAddr,
        port: port,
        username: username,
        password: password,
      );

      if (!isValid) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Text(
                  'Connection failed. Check host, username, port, and password.',
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
        }
        return;
      }

      if (!_isEditing) {
        final newHost = HostModel(
          id: const Uuid().v4(),
          name: name,
          host: hostAddr,
          port: port,
          username: username,
        );
        await provider.addHost(newHost, _passwordController.text);
      } else {
        final updatedHost = widget.host!.copyWith(
          name: name,
          host: hostAddr,
          port: port,
          username: username,
        );
        await provider.updateHost(
          updatedHost,
          _passwordController.text.isEmpty ? null : _passwordController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Environment updated successfully.'
                    : 'Environment created successfully.',
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_isEditing ? 'Edit Environment' : 'Create Environment'),
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
              top: -60,
              right: -30,
              child: _AmbientOrb(
                color: primary.withValues(alpha: 0.14),
                size: 220,
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RevealOnMount(
                        child: _EditorHero(isEditing: _isEditing),
                      ),
                      const SizedBox(height: 18),
                      RevealOnMount(
                        delay: const Duration(milliseconds: 100),
                        child: _FormShell(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('IDENTITY'),
                              _buildTextField(
                                controller: _nameController,
                                label: 'Environment Name',
                                hint: 'Production API',
                                icon: Icons.grid_view_rounded,
                              ),
                              const SizedBox(height: 24),
                              _buildSectionTitle('NETWORK'),
                              _buildTextField(
                                controller: _hostController,
                                label: 'Host or IP',
                                hint: '203.0.113.10 or server.example.com',
                                icon: Icons.language_rounded,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildTextField(
                                      controller: _usernameController,
                                      label: 'Username',
                                      hint: 'deploy',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTextField(
                                      controller: _portController,
                                      label: 'Port',
                                      hint: '22',
                                      icon: Icons.numbers_rounded,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildSectionTitle('AUTHENTICATION'),
                              _buildTextField(
                                controller: _passwordController,
                                label: _isEditing ? 'New Password' : 'Password',
                                hint: _isEditing
                                    ? 'Leave empty to keep current password'
                                    : 'Required for validation',
                                icon: Icons.lock_outline_rounded,
                                obscureText: true,
                                required: !_isEditing,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      RevealOnMount(
                        delay: const Duration(milliseconds: 180),
                        child: _FormShell(
                          child: _isSaving
                              ? const _AddEditHostSkeleton()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Before saving, the app validates the SSH connection so broken environments never land in your workspace.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.66),
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _save,
                                        child: Text(
                                          _isEditing
                                              ? 'Validate and Save'
                                              : 'Validate and Create',
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Text(title, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: !_isSaving,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) {
          return 'This field is required';
        }
        return null;
      },
    );
  }
}

class _EditorHero extends StatelessWidget {
  final bool isEditing;

  const _EditorHero({required this.isEditing});

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
        border: Border.all(color: primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              isEditing ? Icons.tune_rounded : Icons.add_box_rounded,
              color: primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Refine environment access' : 'Add a new environment',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  isEditing
                      ? 'Update connection details without losing the structure of your workspace.'
                      : 'Create a polished, validated SSH target before it reaches your main workspace.',
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

class _FormShell extends StatelessWidget {
  final Widget child;

  const _FormShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _AddEditHostSkeleton extends StatelessWidget {
  const _AddEditHostSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(height: 14, width: 220),
        SizedBox(height: 18),
        SkeletonBox(height: 56),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 56)),
            SizedBox(width: 16),
            Expanded(child: SkeletonBox(height: 56)),
          ],
        ),
        SizedBox(height: 16),
        SkeletonBox(height: 56),
        SizedBox(height: 22),
        SkeletonBox(height: 56),
      ],
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
