import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/host_model.dart';
import '../models/host_secret_model.dart';
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
  static const List<String> _commonAwsUsernames = [
    'ubuntu',
    'ec2-user',
    'admin',
    'root',
  ];

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _privateKeyController;
  late TextEditingController _passphraseController;
  late AuthType _selectedAuthType;

  bool _isSaving = false;

  bool get _isEditing => widget.host != null;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.host?.host ?? '');
    _portController = TextEditingController(
      text: widget.host?.port.toString() ?? '22',
    );
    _usernameController = TextEditingController(
      text: widget.host?.username ?? '',
    );
    _passwordController = TextEditingController();
    _privateKeyController = TextEditingController();
    _passphraseController = TextEditingController();
    _selectedAuthType = widget.host?.authType ?? AuthType.password;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final hostProvider = Provider.of<HostProvider>(context, listen: false);
    final sshService = Provider.of<SSHService>(context, listen: false);

    final hostAddr = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 22;
    final username = _usernameController.text.trim();

    try {
      final existingSecrets = _isEditing
          ? await hostProvider.getSecrets(widget.host!)
          : null;

      final resolved = _resolveSecrets(
        sshService: sshService,
        existingSecrets: existingSecrets,
      );
      if (resolved == null) {
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Verifying updated SSH configuration...'
                    : 'Validating SSH configuration...',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
      }

      final validation = await sshService.testConnection(
        host: hostAddr,
        port: port,
        username: username,
        authType: _selectedAuthType,
        password: resolved.activeSecrets.password,
        privateKey: resolved.activeSecrets.privateKey,
        passphrase: resolved.activeSecrets.passphrase,
      );

      if (!validation.isValid) {
        _showError(validation.message ?? 'SSH validation failed.');
        return;
      }

      if (!_isEditing) {
        final newHost = HostModel(
          id: const Uuid().v4(),
          host: hostAddr,
          port: port,
          username: username,
          authType: _selectedAuthType,
        );
        await hostProvider.addHost(newHost, resolved.secretsToPersist);
      } else {
        final updatedHost = widget.host!.copyWith(
          host: hostAddr,
          port: port,
          username: username,
          authType: _selectedAuthType,
        );
        await hostProvider.updateHost(
          updatedHost,
          secrets: resolved.shouldPersistSecrets
              ? resolved.secretsToPersist
              : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Host updated successfully.'
                    : 'Host created successfully.',
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
      _showError('Unable to save host. $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  _ResolvedSecrets? _resolveSecrets({
    required SSHService sshService,
    HostSecretModel? existingSecrets,
  }) {
    final password = _passwordController.text;
    final privateKey = _privateKeyController.text.trim();
    final passphrase = _passphraseController.text;
    final authTypeChanged =
        _isEditing && widget.host!.authType != _selectedAuthType;

    if (_selectedAuthType == AuthType.password) {
      if (password.isNotEmpty) {
        final secrets = HostSecretModel(
          authType: AuthType.password,
          password: password,
        );
        return _ResolvedSecrets(
          activeSecrets: secrets,
          secretsToPersist: secrets,
          shouldPersistSecrets: true,
        );
      }

      if (!authTypeChanged &&
          existingSecrets != null &&
          existingSecrets.authType == AuthType.password &&
          existingSecrets.hasPassword) {
        return _ResolvedSecrets(
          activeSecrets: existingSecrets,
          secretsToPersist: existingSecrets,
          shouldPersistSecrets: false,
        );
      }

      _showError(
        'Password is required. Credentials are stored securely on your device and are not synced. Please re-enter them after reinstall.',
      );
      return null;
    }

    if (_passphraseController.text.isNotEmpty && privateKey.isEmpty) {
      _showError('Paste the private key again when updating its passphrase.');
      return null;
    }

    if (privateKey.isNotEmpty) {
      final privateKeyError = sshService.validatePrivateKey(
        privateKey: privateKey,
        passphrase: passphrase,
        requirePassphraseIfEncrypted: true,
      );
      if (privateKeyError != null) {
        _showError(privateKeyError);
        return null;
      }

      final secrets = HostSecretModel(
        authType: AuthType.privateKey,
        privateKey: privateKey,
        passphrase: passphrase,
      );
      return _ResolvedSecrets(
        activeSecrets: secrets,
        secretsToPersist: secrets,
        shouldPersistSecrets: true,
      );
    }

    if (!authTypeChanged &&
        existingSecrets != null &&
        existingSecrets.authType == AuthType.privateKey &&
        existingSecrets.hasPrivateKey) {
      return _ResolvedSecrets(
        activeSecrets: existingSecrets,
        secretsToPersist: existingSecrets,
        shouldPersistSecrets: false,
      );
    }

    _showError(
      'Private key is required. Credentials are stored securely on your device and are not synced. Please re-enter them after reinstall.',
    );
    return null;
  }

  Future<void> _pastePrivateKey() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final value = clipboardData?.text?.trim();
    if (value == null || value.isEmpty) {
      _showError('Clipboard does not contain a private key.');
      return;
    }

    setState(() {
      _privateKeyController.text = value;
    });
  }

  Future<void> _pickPrivateKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pem', 'key', 'rsa', 'ppk'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final pickedFile = result.files.single;
    final content = pickedFile.bytes != null
        ? String.fromCharCodes(pickedFile.bytes!)
        : pickedFile.path != null
        ? await File(pickedFile.path!).readAsString()
        : '';
    final normalized = content.trim();

    if (normalized.isEmpty) {
      _showError('The selected file does not contain a private key.');
      return;
    }

    setState(() {
      _privateKeyController.text = normalized;
    });
  }

  void _selectUsername(String username) {
    setState(() {
      _usernameController.text = username;
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_isEditing ? 'Edit Host' : 'Add Host'),
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
                      RevealOnMount(child: _EditorHero(isEditing: _isEditing)),
                      const SizedBox(height: 18),
                      RevealOnMount(
                        delay: const Duration(milliseconds: 100),
                        child: _FormShell(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('CONNECTION'),
                              _buildTextField(
                                controller: _hostController,
                                label: 'Host',
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
                              if (_selectedAuthType == AuthType.privateKey) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Common EC2 usernames',
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'AWS Linux images usually use `ubuntu`, `ec2-user`, or `admin`. Wrong username is one of the most common SSH key login failures.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.68),
                                              height: 1.4,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _commonAwsUsernames
                                            .map(
                                              (username) => ActionChip(
                                                label: Text(username),
                                                onPressed: _isSaving
                                                    ? null
                                                    : () => _selectUsername(
                                                        username,
                                                      ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              _buildSectionTitle('AUTHENTICATION'),
                              _AuthTypeSelector(
                                value: _selectedAuthType,
                                enabled: !_isSaving,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedAuthType = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              if (_selectedAuthType == AuthType.password) ...[
                                _buildTextField(
                                  controller: _passwordController,
                                  label: _isEditing
                                      ? 'New Password'
                                      : 'Password',
                                  hint: _isEditing
                                      ? 'Leave empty to keep the current on-device password'
                                      : 'Stored only on this device',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: true,
                                  requiredField: !_isEditing,
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Paste your PEM private key below. It stays only in secure device storage.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.66),
                                              height: 1.45,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : _pickPrivateKeyFile,
                                      icon: const Icon(
                                        Icons.upload_file_rounded,
                                      ),
                                      label: const Text('Import'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : _pastePrivateKey,
                                      icon: const Icon(
                                        Icons.content_paste_rounded,
                                      ),
                                      label: const Text('Paste Key'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _privateKeyController,
                                  label: _isEditing
                                      ? 'Private Key (Paste to Replace)'
                                      : 'Private Key',
                                  hint: '-----BEGIN RSA PRIVATE KEY-----',
                                  icon: Icons.key_rounded,
                                  maxLines: 8,
                                  requiredField: !_isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _passphraseController,
                                  label: 'Passphrase (Optional)',
                                  hint: 'Required only for encrypted keys',
                                  icon: Icons.password_rounded,
                                  obscureText: true,
                                  requiredField: false,
                                ),
                              ],
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
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.verified_user_outlined,
                                            color: theme.colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Credentials are stored securely on your device and are not synced. Please re-enter them after reinstall.',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: 0.72,
                                                        ),
                                                    height: 1.45,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'This host is validated before saving so wrong usernames, malformed PEM keys, missing authorized_keys entries, bad passphrases, and unreachable servers fail fast.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
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
    bool requiredField = true,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: !_isSaving,
      minLines: maxLines == 1 ? 1 : maxLines,
      maxLines: obscureText ? 1 : maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      validator: (value) {
        if (!requiredField) {
          return null;
        }
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }
}

class _ResolvedSecrets {
  final HostSecretModel activeSecrets;
  final HostSecretModel secretsToPersist;
  final bool shouldPersistSecrets;

  const _ResolvedSecrets({
    required this.activeSecrets,
    required this.secretsToPersist,
    required this.shouldPersistSecrets,
  });
}

class _AuthTypeSelector extends StatelessWidget {
  final AuthType value;
  final bool enabled;
  final ValueChanged<AuthType> onChanged;

  const _AuthTypeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<AuthType>(
          segments: AuthType.values
              .map(
                (type) => ButtonSegment<AuthType>(
                  value: type,
                  icon: Icon(
                    type == AuthType.password
                        ? Icons.lock_outline_rounded
                        : Icons.key_rounded,
                  ),
                  label: Text(type.label),
                ),
              )
              .toList(),
          selected: {value},
          onSelectionChanged: enabled
              ? (selection) => onChanged(selection.first)
              : null,
          showSelectedIcon: false,
        ),
        const SizedBox(height: 12),
        Text(
          value == AuthType.password
              ? 'Authenticate with an SSH password.'
              : 'Authenticate with a PEM private key and optional passphrase.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
          ),
        ),
      ],
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
                  isEditing ? 'Refine SSH access' : 'Add a new SSH host',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Host metadata syncs across devices, but passwords and private keys stay only in secure device storage.',
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
        SkeletonBox(height: 72),
        SizedBox(height: 16),
        SkeletonBox(height: 56),
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
