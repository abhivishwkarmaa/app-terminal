import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/host_model.dart';
import '../models/host_secret_model.dart';
import '../providers/host_provider.dart';
import '../services/mysql_service.dart';
import 'widgets/skeleton.dart';

class AddEditMySqlScreen extends StatefulWidget {
  final HostModel? connection;

  const AddEditMySqlScreen({super.key, this.connection});

  @override
  State<AddEditMySqlScreen> createState() => _AddEditMySqlScreenState();
}

class _AddEditMySqlScreenState extends State<AddEditMySqlScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '3306');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final MySqlService _mySqlService = MySqlService();

  HostSecretModel? _existingSecrets;
  List<String> _databases = const [];
  String? _selectedDatabase;
  bool _isLoading = false;
  bool _isFetchingDatabases = false;

  bool get _isEditing => widget.connection != null;

  @override
  void initState() {
    super.initState();
    final connection = widget.connection;
    if (connection != null) {
      _nameController.text = connection.displayName;
      _hostController.text = connection.host;
      _portController.text = connection.port.toString();
      _usernameController.text = connection.username;
      _selectedDatabase = connection.databaseName;
      _loadExistingSecret();
    }
  }

  Future<void> _loadExistingSecret() async {
    final provider = Provider.of<HostProvider>(context, listen: false);
    final secrets = await provider.getSecrets(widget.connection!);
    if (!mounted || secrets == null) return;
    setState(() {
      _existingSecrets = secrets;
    });
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

  void _showFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _fetchDatabases() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text.trim().isNotEmpty
        ? _passwordController.text
        : _existingSecrets?.password;
    if (password == null || password.isEmpty) {
      _showFeedback('Password is required to fetch databases.', isError: true);
      return;
    }

    setState(() => _isFetchingDatabases = true);
    try {
      final databases = await _mySqlService.fetchDatabases(
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        username: _usernameController.text.trim(),
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _databases = databases;
        _selectedDatabase ??= databases.isNotEmpty ? databases.first : null;
      });
      _showFeedback('Databases loaded successfully.');
    } catch (e) {
      _showFeedback('Failed to load databases: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isFetchingDatabases = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = Provider.of<HostProvider>(context, listen: false);

    final password = _passwordController.text.trim().isNotEmpty
        ? _passwordController.text
        : _existingSecrets?.password;
    if (password == null || password.isEmpty) {
      _showFeedback(
        'Password is required for MySQL connections.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _mySqlService.testConnection(
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        username: _usernameController.text.trim(),
        password: password,
        database: _selectedDatabase,
      );

      final connection = HostModel(
        id: widget.connection?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        connectionType: ConnectionType.mysql,
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        username: _usernameController.text.trim(),
        authType: AuthType.password,
        databaseName: _selectedDatabase,
      );

      final secrets = HostSecretModel(
        authType: AuthType.password,
        password: password,
      );

      if (_isEditing) {
        await provider.updateHost(connection, secrets: secrets);
      } else {
        await provider.addHost(connection, secrets);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showFeedback('MySQL connection failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit MySQL Connection' : 'Add MySQL Connection',
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Connection Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hostController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Host / IP',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Host is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _portController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final port = int.tryParse(value ?? '');
                      if (port == null || port <= 0) {
                        return 'Enter a valid port';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Username is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: _isEditing && _existingSecrets != null
                          ? 'Password (leave blank to keep saved)'
                          : 'Password',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isFetchingDatabases || _isLoading
                              ? null
                              : _fetchDatabases,
                          icon: _isFetchingDatabases
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            _isFetchingDatabases
                                ? 'Loading databases...'
                                : 'Fetch Databases',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isFetchingDatabases)
                    const _DatabaseDropdownSkeleton()
                  else if (_databases.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDatabase,
                      items: _databases
                          .map(
                            (db) => DropdownMenuItem<String>(
                              value: db,
                              child: Text(db),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _selectedDatabase = value;
                              });
                            },
                      decoration: const InputDecoration(
                        labelText: 'Default Database',
                        border: OutlineInputBorder(),
                      ),
                    )
                  else
                    Text(
                      'Fetch databases to choose a default DB, or leave it blank and choose later in the workbench.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                        height: 1.45,
                      ),
                    ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isLoading
                          ? (_isEditing
                                ? 'Validating connection...'
                                : 'Creating connection...')
                          : (_isEditing
                                ? 'Save Connection'
                                : 'Save MySQL Connection'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const Positioned.fill(child: _MySqlSavingOverlay()),
        ],
      ),
    );
  }
}

class _DatabaseDropdownSkeleton extends StatelessWidget {
  const _DatabaseDropdownSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(height: 14, width: 140),
        SizedBox(height: 8),
        SkeletonBox(height: 56),
      ],
    );
  }
}

class _MySqlSavingOverlay extends StatelessWidget {
  const _MySqlSavingOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AbsorbPointer(
      child: Container(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.68),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SkeletonCard(
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Validating MySQL connection...',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Checking credentials, host reachability, and database access.',
                    ),
                    SizedBox(height: 16),
                    SkeletonBox(height: 12, width: 180),
                    SizedBox(height: 10),
                    SkeletonBox(height: 48),
                    SizedBox(height: 10),
                    SkeletonBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
