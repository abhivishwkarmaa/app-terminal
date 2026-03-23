import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:path_provider/path_provider.dart';

class MySqlService {
  Future<MySQLConnection> _openConnection({
    required String host,
    required int port,
    required String username,
    required String password,
    String? database,
  }) async {
    final connection = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: username,
      password: password,
      databaseName: database != null && database.trim().isNotEmpty
          ? database.trim()
          : null,
      secure: true,
    );
    await connection.connect(timeoutMs: 12000);
    return connection;
  }

  Future<void> testConnection({
    required String host,
    required int port,
    required String username,
    required String password,
    String? database,
  }) async {
    final connection = await _openConnection(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database,
    );
    await connection.close();
  }

  Future<List<String>> fetchDatabases({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    final connection = await _openConnection(
      host: host,
      port: port,
      username: username,
      password: password,
    );

    try {
      final results = await connection.execute('SHOW DATABASES');
      return results.rows
          .map((row) => row.colAt(0) ?? '')
          .where((db) => db.isNotEmpty)
          .toList();
    } finally {
      await connection.close();
    }
  }

  Future<List<String>> fetchTables({
    required String host,
    required int port,
    required String username,
    required String password,
    required String database,
  }) async {
    final connection = await _openConnection(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database,
    );

    try {
      final results = await connection.execute('SHOW TABLES');
      return results.rows
          .map((row) => row.colAt(0) ?? '')
          .where((table) => table.isNotEmpty)
          .toList();
    } finally {
      await connection.close();
    }
  }

  Future<Map<String, List<String>>> fetchTableColumns({
    required String host,
    required int port,
    required String username,
    required String password,
    required String database,
  }) async {
    final connection = await _openConnection(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database,
    );

    try {
      final results = await connection.execute(
        '''
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = :database
        ORDER BY table_name, ordinal_position
        ''',
        {'database': database},
      );

      final tableColumns = <String, List<String>>{};
      for (final row in results.rows) {
        final tableName = row.colByName('table_name') ?? '';
        final columnName = row.colByName('column_name') ?? '';
        if (tableName.isEmpty || columnName.isEmpty) continue;
        tableColumns.putIfAbsent(tableName, () => <String>[]).add(columnName);
      }
      return tableColumns;
    } finally {
      await connection.close();
    }
  }

  Future<MySqlQueryResult> executeQuery({
    required String host,
    required int port,
    required String username,
    required String password,
    String? database,
    required String query,
  }) async {
    final connection = await _openConnection(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database,
    );

    try {
      final results = await connection.execute(query.trim());
      final columns = results.cols
          .map((field) => field.name.trim().isNotEmpty ? field.name : 'column')
          .toList();
      final rows = results.rows
          .map(
            (row) => columns
                .map((column) => row.colByName(column) ?? 'NULL')
                .toList(),
          )
          .toList();

      return MySqlQueryResult(
        columns: columns,
        rows: rows,
        affectedRows: int.tryParse(results.affectedRows.toString()) ?? 0,
        insertId: int.tryParse(results.lastInsertID.toString()),
        executedQuery: query.trim(),
      );
    } finally {
      await connection.close();
    }
  }

  String buildCopyText(MySqlQueryResult result) {
    if (!result.hasRows) {
      final buffer = StringBuffer();
      buffer.writeln('Query: ${result.executedQuery}');
      buffer.writeln('Affected rows: ${result.affectedRows}');
      if (result.insertId != null) {
        buffer.writeln('Insert ID: ${result.insertId}');
      }
      return buffer.toString().trim();
    }

    final buffer = StringBuffer();
    buffer.writeln(result.columns.join('\t'));
    for (final row in result.rows) {
      buffer.writeln(row.join('\t'));
    }
    return buffer.toString().trim();
  }

  Future<String> exportCsv(
    MySqlQueryResult result, {
    String filePrefix = 'mysql_query_result',
  }) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final csv = _toCsv(result);
    return _saveSingleFile(
      fileName: '$filePrefix-$timestamp.csv',
      content: csv,
    );
  }

  Future<String> exportDatabaseAsSqlDump({
    required String host,
    required int port,
    required String username,
    required String password,
    required String database,
    List<String>? tables,
    bool exportStructure = true,
    bool exportData = true,
    Function(ExportProgress)? onProgress,
  }) async {
    final connection = await _openConnection(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database,
    );

    try {
      final resolvedTables = tables ?? await fetchTables(
        host: host,
        port: port,
        username: username,
        password: password,
        database: database,
      );
      final totalTables = resolvedTables.length;
      final startTime = DateTime.now();

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

      final buffer = StringBuffer()
        ..writeln('-- TermSSH MySQL export')
        ..writeln('-- Database: $database')
        ..writeln('-- Generated: ${DateTime.now().toIso8601String()}')
        ..writeln();

      if (exportStructure) {
        buffer
          ..writeln('CREATE DATABASE IF NOT EXISTS `${_escapeIdentifier(database)}`;')
          ..writeln('USE `${_escapeIdentifier(database)}`;')
          ..writeln();
      } else {
        buffer
          ..writeln('USE `${_escapeIdentifier(database)}`;')
          ..writeln();
      }

      for (int i = 0; i < resolvedTables.length; i++) {
        final table = resolvedTables[i];
        
        // Report progress
        if (onProgress != null) {
          final elapsed = DateTime.now().difference(startTime);
          final progress = (i / totalTables);
          Duration? remaining;
          if (progress > 0) {
            final totalEstimated = elapsed * (1.0 / progress);
            remaining = totalEstimated - elapsed;
          }
          onProgress(ExportProgress(
            status: 'Processing table: $table',
            progress: progress,
            timeRemaining: remaining,
          ));
        }

        if (exportStructure) {
          final createTable = await _fetchCreateTableStatement(connection, table);
          buffer
            ..writeln('--')
            ..writeln('-- Table structure for `$table`')
            ..writeln('--')
            ..writeln('DROP TABLE IF EXISTS `${_escapeIdentifier(table)}`;')
            ..writeln('$createTable;')
            ..writeln();
        }

        if (exportData) {
          final tableDump = await _buildTableInsertDump(connection, table);
          if (tableDump.isNotEmpty) {
            buffer
              ..writeln('--')
              ..writeln('-- Data for `$table`')
              ..writeln('--')
              ..write(tableDump)
            ..writeln();
          }
        }
      }

      if (onProgress != null) {
        onProgress(ExportProgress(
          status: 'Saving file...',
          progress: 1.0,
          timeRemaining: Duration.zero,
        ));
      }

      return _saveSingleFile(
        fileName: '${database}_dump_$timestamp.sql',
        content: buffer.toString(),
      );
    } finally {
      await connection.close();
    }
  }

  Future<String> exportDatabaseAsTableFiles({
    required String host,
    required int port,
    required String username,
    required String password,
    required String database,
    List<String>? tables,
    bool exportStructure = true,
    bool exportData = true,
    Function(ExportProgress)? onProgress,
  }) async {
    // 1. Pick directory FIRST as requested by user
    DirectoryLocation? pickedDirectory;
    if (_supportsNativeSaveDialog) {
       if (!await FlutterFileDialog.isPickDirectorySupported()) {
          throw Exception('Directory picker not supported on this device');
        }
        pickedDirectory = await FlutterFileDialog.pickDirectory();
        if (pickedDirectory == null) {
          throw Exception('Folder selection cancelled');
        }
    }

    final connection = await _openConnection(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database,
    );

    try {
      final resolvedTables = tables ?? await fetchTables(
        host: host,
        port: port,
        username: username,
        password: password,
        database: database,
      );
      final totalTables = resolvedTables.length;
      final startTime = DateTime.now();
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final schemaBuffer = StringBuffer();
      
      if (exportStructure) {
        schemaBuffer
          ..writeln('-- TermSSH table export')
          ..writeln('-- Database: $database')
          ..writeln();
      }
      final tableCsvFiles = <String, String>{};

      for (int i = 0; i < resolvedTables.length; i++) {
        final table = resolvedTables[i];

        // Report progress
        if (onProgress != null) {
          final elapsed = DateTime.now().difference(startTime);
          final progress = (i / totalTables);
          Duration? remaining;
          if (progress > 0) {
            final totalEstimated = elapsed * (1.0 / progress);
            remaining = totalEstimated - elapsed;
          }
          onProgress(ExportProgress(
            status: 'Exporting table: $table',
            progress: progress,
            timeRemaining: remaining,
          ));
        }

        if (exportStructure) {
          final createTable = await _fetchCreateTableStatement(connection, table);
          schemaBuffer
            ..writeln('DROP TABLE IF EXISTS `${_escapeIdentifier(table)}`;')
            ..writeln('$createTable;')
            ..writeln();
        }

        if (exportData) {
          final queryResult = await _buildTableQueryResult(connection, table);
          tableCsvFiles[_escapeFileName(table)] = _toCsv(queryResult);
        }
      }

      if (onProgress != null) {
        onProgress(ExportProgress(
          status: 'Writing files...',
          progress: 0.99,
          timeRemaining: Duration.zero,
        ));
      }

      return _saveFolderExport(
        folderName: '${database}_tables_$timestamp',
        schemaSql: exportStructure ? schemaBuffer.toString() : null,
        tableCsvFiles: tableCsvFiles,
        prePickedDirectory: pickedDirectory,
      );
    } finally {
      await connection.close();
    }
  }

  String _toCsv(MySqlQueryResult result) {
    final lines = <String>[];

    if (result.hasRows) {
      lines.add(result.columns.map(_escapeCsv).join(','));
      for (final row in result.rows) {
        lines.add(row.map(_escapeCsv).join(','));
      }
      return lines.join('\n');
    }

    lines.add('query,affected_rows,insert_id');
    lines.add(
      [
        _escapeCsv(result.executedQuery),
        '${result.affectedRows}',
        result.insertId?.toString() ?? '',
      ].join(','),
    );
    return lines.join('\n');
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<String> _fetchCreateTableStatement(
    MySQLConnection connection,
    String table,
  ) async {
    final result = await connection.execute(
      'SHOW CREATE TABLE `${_escapeIdentifier(table)}`',
    );
    for (final row in result.rows) {
      final statement = row.colAt(1);
      if (statement != null && statement.trim().isNotEmpty) {
        return statement.trim();
      }
    }
    throw Exception('Unable to load CREATE TABLE for $table');
  }

  Future<String> _buildTableInsertDump(
    MySQLConnection connection,
    String table,
  ) async {
    final result = await connection.execute(
      'SELECT * FROM `${_escapeIdentifier(table)}`',
    );
    final columns = result.cols.map((column) => column.name).toList();
    if (columns.isEmpty || result.rows.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final row in result.rows) {
      final values = columns
          .map((column) => _escapeSqlValue(row.colByName(column)))
          .join(', ');
      buffer.writeln(
        'INSERT INTO `${_escapeIdentifier(table)}` (${columns.map((column) => '`${_escapeIdentifier(column)}`').join(', ')}) VALUES ($values);',
      );
    }
    return buffer.toString();
  }

  Future<MySqlQueryResult> _buildTableQueryResult(
    MySQLConnection connection,
    String table,
  ) async {
    final result = await connection.execute(
      'SELECT * FROM `${_escapeIdentifier(table)}`',
    );
    final columns = result.cols
        .map((field) => field.name.trim().isNotEmpty ? field.name : 'column')
        .toList();
    final rows = result.rows
        .map(
          (row) => columns
              .map((column) => row.colByName(column) ?? 'NULL')
              .toList(),
        )
        .toList();

    return MySqlQueryResult(
      columns: columns,
      rows: rows,
      affectedRows: int.tryParse(result.affectedRows.toString()) ?? 0,
      insertId: int.tryParse(result.lastInsertID.toString()),
      executedQuery: 'SELECT * FROM `${_escapeIdentifier(table)}`',
    );
  }

  Future<String> _saveSingleFile({
    required String fileName,
    required String content,
  }) async {
    if (_supportsNativeSaveDialog) {
      final tempFile = await _writeTempFile(fileName, content);
      try {
        final savedPath = await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(sourceFilePath: tempFile.path),
        );
        if (savedPath == null || savedPath.isEmpty) {
          throw Exception('Save cancelled');
        }
        return savedPath;
      } on MissingPluginException {
        throw Exception(
          'Native export plugin not loaded. Please completely STOP the app and run "flutter run" again.',
        );
      } catch (e) {
        throw Exception('Failed to save file: $e');
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    return file.path;
  }

  Future<String> _saveFolderExport({
    required String folderName,
    String? schemaSql,
    required Map<String, String> tableCsvFiles,
    DirectoryLocation? prePickedDirectory,
  }) async {
    if (_supportsNativeSaveDialog) {
      try {
        DirectoryLocation? pickedDirectory = prePickedDirectory;
        if (pickedDirectory == null) {
          if (!await FlutterFileDialog.isPickDirectorySupported()) {
            throw Exception('Directory picker not supported on this device');
          }
          pickedDirectory = await FlutterFileDialog.pickDirectory();
        }

        if (pickedDirectory == null) {
          throw Exception('Folder selection cancelled');
        }

        if (schemaSql != null && schemaSql.trim().isNotEmpty) {
          await FlutterFileDialog.saveFileToDirectory(
            directory: pickedDirectory,
            data: Uint8List.fromList(schemaSql.codeUnits),
            mimeType: 'application/sql',
            fileName: 'schema.sql',
            replace: true,
          );
        }

        for (final entry in tableCsvFiles.entries) {
          await FlutterFileDialog.saveFileToDirectory(
            directory: pickedDirectory,
            data: Uint8List.fromList(entry.value.codeUnits),
            mimeType: 'text/csv',
            fileName: '${entry.key}.csv',
            replace: true,
          );
        }

        return pickedDirectory.toString();
      } on MissingPluginException {
        throw Exception(
          'Native export plugin not loaded. Please completely STOP the app and run "flutter run" again.',
        );
      } catch (e) {
        throw Exception(e.toString());
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/$folderName');
    await exportDir.create(recursive: true);

    if (schemaSql != null && schemaSql.trim().isNotEmpty) {
      await File('${exportDir.path}/schema.sql').writeAsString(schemaSql);
    }
    for (final entry in tableCsvFiles.entries) {
      await File('${exportDir.path}/${entry.key}.csv').writeAsString(
        entry.value,
      );
    }
    return exportDir.path;
  }

  Future<File> _writeTempFile(String fileName, String content) async {
    final tempDirectory = await getTemporaryDirectory();
    final file = File('${tempDirectory.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }

  String _escapeSqlValue(String? value) {
    if (value == null) return 'NULL';
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return "'$escaped'";
  }

  String _escapeIdentifier(String value) {
    return value.replaceAll('`', '``');
  }

  String _escapeFileName(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
  }

  bool get _supportsNativeSaveDialog =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}

class MySqlQueryResult {
  final List<String> columns;
  final List<List<String>> rows;
  final int affectedRows;
  final int? insertId;
  final String executedQuery;

  const MySqlQueryResult({
    required this.columns,
    required this.rows,
    required this.affectedRows,
    required this.insertId,
    required this.executedQuery,
  });

  bool get hasRows => columns.isNotEmpty && rows.isNotEmpty;
}
class ExportProgress {
  final String status;
  final double progress;
  final Duration? timeRemaining;

  const ExportProgress({
    required this.status,
    required this.progress,
    this.timeRemaining,
  });

  String get timeRemainingLabel {
    if (timeRemaining == null) return '';
    final minutes = timeRemaining!.inMinutes;
    final seconds = timeRemaining!.inSeconds % 60;
    if (minutes > 0) {
      return '($minutes min $seconds sec left)';
    }
    return '($seconds sec left)';
  }
}
