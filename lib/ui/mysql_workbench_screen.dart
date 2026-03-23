import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/host_model.dart';
import '../models/host_secret_model.dart';
import '../providers/host_provider.dart';
import '../services/mysql_service.dart';
import '../services/sql_suggestion_service.dart';
import 'widgets/skeleton.dart';

class MySqlWorkbenchScreen extends StatefulWidget {
  final HostModel connection;

  const MySqlWorkbenchScreen({super.key, required this.connection});

  @override
  State<MySqlWorkbenchScreen> createState() => _MySqlWorkbenchScreenState();
}

class _MySqlWorkbenchScreenState extends State<MySqlWorkbenchScreen> {
  final MySqlService _mySqlService = MySqlService();
  final SqlSuggestionService _suggestionService = SqlSuggestionService();
  final TextEditingController _queryController = TextEditingController(
    text: 'SHOW TABLES;',
  );

  HostSecretModel? _secrets;
  List<String> _databases = const [];
  List<String> _tables = const [];
  Map<String, List<String>> _tableColumns = const {};
  List<SqlSuggestion> _suggestions = const [];
  String? _selectedDatabase;
  MySqlQueryResult? _lastResult;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isRunningQuery = false;
  bool _isExporting = false;
  ExportProgress? _exportProgress;

  @override
  void initState() {
    super.initState();
    _selectedDatabase = widget.connection.databaseName;
    _queryController.addListener(_refreshSuggestions);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _queryController.removeListener(_refreshSuggestions);
    _queryController.dispose();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
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

  Future<void> _bootstrap() async {
    final hostProvider = Provider.of<HostProvider>(context, listen: false);
    final existingSecrets = await hostProvider.getSecrets(widget.connection);

    if (!mounted) return;

    if (existingSecrets == null || existingSecrets.password == null) {
      final prompted = await _promptForPassword();
      if (prompted == null) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      try {
        await _mySqlService.testConnection(
          host: widget.connection.host,
          port: widget.connection.port,
          username: widget.connection.username,
          password: prompted.password!,
          database: _selectedDatabase,
        );
        _secrets = prompted;
        await hostProvider.saveSecrets(widget.connection, prompted);
      } catch (e) {
        if (!mounted) return;
        _showFeedback(
          'Unable to connect with that password: $e',
          isError: true,
        );
        Navigator.of(context).maybePop();
        return;
      }
    } else {
      _secrets = existingSecrets;
    }

    try {
      final databases = await _mySqlService.fetchDatabases(
        host: widget.connection.host,
        port: widget.connection.port,
        username: widget.connection.username,
        password: _secrets!.password!,
      );

      if (!mounted) return;

      setState(() {
        _databases = databases;
        _selectedDatabase ??= databases.isNotEmpty ? databases.first : null;
        _isLoading = false;
      });

      await _loadSchemaMetadata();
      await _runQuery();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSchemaMetadata() async {
    final password = _secrets?.password;
    final database = _selectedDatabase;
    if (password == null ||
        password.isEmpty ||
        database == null ||
        database.isEmpty) {
      if (!mounted) return;
      setState(() {
        _tables = const [];
        _tableColumns = const {};
        _refreshSuggestions();
      });
      return;
    }

    try {
      final tables = await _mySqlService.fetchTables(
        host: widget.connection.host,
        port: widget.connection.port,
        username: widget.connection.username,
        password: password,
        database: database,
      );
      final tableColumns = await _mySqlService.fetchTableColumns(
        host: widget.connection.host,
        port: widget.connection.port,
        username: widget.connection.username,
        password: password,
        database: database,
      );

      if (!mounted) return;
      setState(() {
        _tables = tables;
        _tableColumns = tableColumns;
      });
      _refreshSuggestions();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tables = const [];
        _tableColumns = const {};
      });
      _refreshSuggestions();
    }
  }

  void _refreshSuggestions() {
    final selection = _queryController.selection;
    final cursorOffset = selection.isValid
        ? selection.baseOffset
        : _queryController.text.length;

    final suggestions = _suggestionService.buildSuggestions(
      query: _queryController.text,
      cursorOffset: cursorOffset,
      databases: _databases,
      tables: _tables,
      tableColumns: _tableColumns,
    );

    if (!mounted) return;
    setState(() {
      _suggestions = suggestions;
    });
  }

  void _applySuggestion(SqlSuggestion suggestion) {
    final selection = _queryController.selection;
    final cursorOffset = selection.isValid
        ? selection.baseOffset
        : _queryController.text.length;
    final updatedText = _suggestionService.applySuggestion(
      query: _queryController.text,
      cursorOffset: cursorOffset,
      suggestion: suggestion,
    );
    final nextOffset = _suggestionService.nextCursorOffset(
      query: _queryController.text,
      cursorOffset: cursorOffset,
      suggestion: suggestion,
    );

    _queryController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    _refreshSuggestions();
  }

  Future<HostSecretModel?> _promptForPassword() {
    final controller = TextEditingController();

    return showDialog<HostSecretModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('MySQL Password Required'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Database Password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final password = controller.text;
                if (password.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  HostSecretModel(
                    authType: AuthType.password,
                    password: password,
                  ),
                );
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runQuery() async {
    final password = _secrets?.password;
    if (password == null || password.isEmpty) {
      _showFeedback('Missing MySQL password.', isError: true);
      return;
    }

    if (_queryController.text.trim().isEmpty) {
      _showFeedback('Enter a query first.', isError: true);
      return;
    }

    setState(() {
      _isRunningQuery = true;
      _errorMessage = null;
    });

    try {
      final result = await _mySqlService.executeQuery(
        host: widget.connection.host,
        port: widget.connection.port,
        username: widget.connection.username,
        password: password,
        database: _selectedDatabase,
        query: _queryController.text,
      );

      if (!mounted) return;

      setState(() {
        _lastResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _isRunningQuery = false);
      }
    }
  }

  Future<void> _copyResult() async {
    final result = _lastResult;
    if (result == null) {
      _showFeedback('Run a query first.', isError: true);
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: _mySqlService.buildCopyText(result)),
    );
    _showFeedback('Query result copied.');
  }

  Future<void> _exportQueryResult() async {
    final result = _lastResult;
    if (result == null) {
      _showFeedback('Run a query first.', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    try {
      final path = await _mySqlService.exportCsv(result);
      _showFeedback('Query CSV exported to $path');
    } catch (e) {
      _showFeedback('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportDatabase(_ExportChoice choice) async {
    if (_isExporting) return;

    bool exportStructure = true;
    bool exportData = true;

    // Show sub-choices dialog (Structure/Data/Both)
    final subChoice = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Export Options'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'What should be included in the export?',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: (exportStructure && exportData)
                        ? 'Both'
                        : (exportStructure ? 'Structure Only' : 'Data Only'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Both',
                        child: Text('Data + Structure'),
                      ),
                      DropdownMenuItem(
                        value: 'Structure Only',
                        child: Text('Structure Only'),
                      ),
                      DropdownMenuItem(
                        value: 'Data Only',
                        child: Text('Data Only'),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == 'Both') {
                          exportStructure = true;
                          exportData = true;
                        } else if (val == 'Structure Only') {
                          exportStructure = true;
                          exportData = false;
                        } else {
                          exportStructure = false;
                          exportData = true;
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'structure': exportStructure,
                    'data': exportData,
                  }),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (subChoice == null) return;
    exportStructure = subChoice['structure'] ?? true;
    exportData = subChoice['data'] ?? true;

    List<String>? selectedTables;
    if (choice == _ExportChoice.tableFolder) {
      selectedTables = await _showTableSelectionDialog();
      if (selectedTables == null || selectedTables.isEmpty) {
        return;
      }
    }

    setState(() => _isExporting = true);

    try {
      final password = _secrets?.password;
      final database = _selectedDatabase;
      if (password == null || database == null) {
        _showFeedback('Select a database first.', isError: true);
        return;
      }

      void progressCallback(ExportProgress p) {
        setState(() {
          _exportProgress = p;
        });
      }

      if (choice == _ExportChoice.databaseSql) {
        final path = await _mySqlService.exportDatabaseAsSqlDump(
          host: widget.connection.host,
          port: widget.connection.port,
          username: widget.connection.username,
          password: password,
          database: database,
          tables: _tables,
          exportStructure: exportStructure,
          exportData: exportData,
          onProgress: progressCallback,
        );
        _showFeedback('SQL dump exported to $path');
      } else if (choice == _ExportChoice.tableFolder) {
        final path = await _mySqlService.exportDatabaseAsTableFiles(
          host: widget.connection.host,
          port: widget.connection.port,
          username: widget.connection.username,
          password: password,
          database: database,
          tables: selectedTables!,
          exportStructure: exportStructure,
          exportData: exportData,
          onProgress: progressCallback,
        );
        _showFeedback('Table files exported to $path');
      }
    } catch (e) {
      _showFeedback('Export failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportProgress = null;
        });
      }
    }
  }

  Future<List<String>?> _showTableSelectionDialog() async {
    final tempSelected = List<String>.from(_tables);

    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allSelected = tempSelected.length == _tables.length;
            return AlertDialog(
              title: const Text('Select Tables to Export'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text(
                        'Select All',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: allSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            tempSelected.clear();
                            tempSelected.addAll(_tables);
                          } else {
                            tempSelected.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _tables.length,
                        itemBuilder: (context, index) {
                          final table = _tables[index];
                          final isSelected = tempSelected.contains(table);
                          return CheckboxListTile(
                            title: Text(table),
                            value: isSelected,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  tempSelected.add(table);
                                } else {
                                  tempSelected.remove(table);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.connection.displayName),
        actions: [
          IconButton(
            onPressed: _copyResult,
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy result',
          ),
          PopupMenuButton<_ExportChoice>(
            tooltip: 'Export Options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: _exportDatabase,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _ExportChoice.databaseSql,
                child: ListTile(
                  leading: Icon(Icons.description_rounded),
                  title: Text('Export DB as SQL Dump'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: _ExportChoice.tableFolder,
                child: ListTile(
                  leading: Icon(Icons.folder_zip_rounded),
                  title: Text('Export DB as Table Files'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const _MySqlWorkbenchSkeleton()
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _WorkbenchSection(
                        title: 'Connection',
                        child: Text(
                          '${widget.connection.username}@${widget.connection.host}:${widget.connection.port}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _WorkbenchSection(
                        title: 'Database',
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedDatabase,
                          items: _databases
                              .map(
                                (db) => DropdownMenuItem<String>(
                                  value: db,
                                  child: Text(db),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDatabase = value;
                            });
                            _loadSchemaMetadata();
                          },
                          decoration: const InputDecoration(
                            labelText: 'Choose database',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _WorkbenchSection(
                        title: 'Query Editor',
                        child: Column(
                          children: [
                            TextField(
                              controller: _queryController,
                              minLines: 7,
                              maxLines: 10,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Write SQL here',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (_suggestions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Suggestions',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 44,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _suggestions.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final suggestion = _suggestions[index];
                                    return ActionChip(
                                      avatar: Icon(
                                        _iconForSuggestion(suggestion.kind),
                                        size: 16,
                                      ),
                                      label: Text(suggestion.value),
                                      tooltip: suggestion.detail,
                                      onPressed: () =>
                                          _applySuggestion(suggestion),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    _queryController.text = 'SHOW TABLES;';
                                    _refreshSuggestions();
                                  },
                                  child: const Text('SHOW TABLES'),
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    _queryController.text =
                                        'SELECT * FROM your_table LIMIT 50;';
                                    _refreshSuggestions();
                                  },
                                  child: const Text('SELECT LIMIT 50'),
                                ),
                                FilledButton.icon(
                                  onPressed: _isRunningQuery ? null : _runQuery,
                                  icon: _isRunningQuery
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Run Query'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _WorkbenchSection(
                        title: 'Results',
                        child: _ResultPanel(
                          result: _lastResult,
                          errorMessage: _errorMessage,
                          isExporting: _isExporting,
                          onExportQuery: _exportQueryResult,
                        ),
                      ),
                    ],
                  ),
                ),
          if (_exportProgress != null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Exporting Database',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _exportProgress!.progress,
                        ),
                        const SizedBox(height: 16),
                        Text(_exportProgress!.status),
                        if (_exportProgress!.timeRemainingLabel.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _exportProgress!.timeRemainingLabel,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          '${(_exportProgress!.progress * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForSuggestion(SqlSuggestionKind kind) {
    switch (kind) {
      case SqlSuggestionKind.keyword:
        return Icons.code_rounded;
      case SqlSuggestionKind.database:
        return Icons.storage_rounded;
      case SqlSuggestionKind.table:
        return Icons.table_chart_rounded;
      case SqlSuggestionKind.column:
        return Icons.view_column_rounded;
    }
  }
}

class _MySqlWorkbenchSkeleton extends StatelessWidget {
  const _MySqlWorkbenchSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 18, width: 110),
                SizedBox(height: 12),
                SkeletonBox(height: 20, width: 260),
              ],
            ),
          ),
          SizedBox(height: 16),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 18, width: 90),
                SizedBox(height: 12),
                SkeletonBox(height: 56),
              ],
            ),
          ),
          SizedBox(height: 16),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 18, width: 110),
                SizedBox(height: 12),
                SkeletonBox(height: 150),
                SizedBox(height: 12),
                SkeletonBox(height: 44),
              ],
            ),
          ),
          SizedBox(height: 16),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 18, width: 80),
                SizedBox(height: 12),
                SkeletonBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ExportChoice { databaseSql, tableFolder }

class _WorkbenchSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _WorkbenchSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ResultPanel extends StatefulWidget {
  final MySqlQueryResult? result;
  final String? errorMessage;
  final bool isExporting;
  final VoidCallback onExportQuery;

  const _ResultPanel({
    required this.result,
    required this.errorMessage,
    required this.isExporting,
    required this.onExportQuery,
  });

  @override
  State<_ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends State<_ResultPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.errorMessage != null) {
      return Text(
        widget.errorMessage!,
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
      );
    }

    if (widget.result == null) {
      return Text(
        'Run a query to see rows, affected count, and export actions here.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.result!.hasRows)
                  Text(
                    'Rows: ${widget.result!.rows.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                else
                  Text(
                    'Affected rows: ${widget.result!.affectedRows}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (widget.result!.insertId != null)
                  Text('Last Insert ID: ${widget.result!.insertId}'),
              ],
            ),
            if (widget.isExporting)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                onPressed: widget.onExportQuery,
                icon: const Icon(
                  Icons.file_download_rounded,
                  color: Colors.blue,
                ),
                tooltip: 'Download result as CSV',
              ),
          ],
        ),
        if (widget.result!.hasRows) ...[
          const SizedBox(height: 12),
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: widget.result!.columns
                    .map((col) => DataColumn(label: Text(col)))
                    .toList(),
                rows: widget.result!.rows
                    .map(
                      (row) => DataRow(
                        cells: row
                            .map((cell) => DataCell(SelectableText(cell)))
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
