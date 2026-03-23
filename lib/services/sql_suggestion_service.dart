enum SqlSuggestionKind { keyword, database, table, column }

class SqlSuggestion {
  final SqlSuggestionKind kind;
  final String value;
  final String replacement;
  final String? detail;

  const SqlSuggestion({
    required this.kind,
    required this.value,
    required this.replacement,
    this.detail,
  });
}

class SqlSuggestionService {
  static const List<String> _keywords = [
    'SELECT',
    'FROM',
    'WHERE',
    'INSERT INTO',
    'UPDATE',
    'DELETE FROM',
    'JOIN',
    'LEFT JOIN',
    'RIGHT JOIN',
    'INNER JOIN',
    'ORDER BY',
    'GROUP BY',
    'HAVING',
    'LIMIT',
    'SHOW TABLES',
    'SHOW DATABASES',
    'DESCRIBE',
    'USE',
    'CREATE TABLE',
    'ALTER TABLE',
    'DROP TABLE',
    'COUNT',
    'SUM',
    'AVG',
    'MIN',
    'MAX',
    'DISTINCT',
  ];

  List<SqlSuggestion> buildSuggestions({
    required String query,
    required int cursorOffset,
    required List<String> databases,
    required List<String> tables,
    required Map<String, List<String>> tableColumns,
  }) {
    final offset = cursorOffset.clamp(0, query.length);
    final tokenRange = currentTokenRange(query, offset);
    final prefix = query.substring(tokenRange.start, tokenRange.end);
    final beforeToken = query.substring(0, tokenRange.start);
    final context = _detectContext(beforeToken, prefix);

    if (prefix.contains('.')) {
      return _buildQualifiedColumnSuggestions(prefix, tableColumns);
    }

    final candidates = <SqlSuggestion>[
      if (context.includeKeywords)
        ..._keywords.map(
          (keyword) => SqlSuggestion(
            kind: SqlSuggestionKind.keyword,
            value: keyword,
            replacement: '$keyword ',
          ),
        ),
      if (context.includeDatabases)
        ...databases.map(
          (database) => SqlSuggestion(
            kind: SqlSuggestionKind.database,
            value: database,
            replacement: '$database ',
            detail: 'Database',
          ),
        ),
      if (context.includeTables)
        ...tables.map(
          (table) => SqlSuggestion(
            kind: SqlSuggestionKind.table,
            value: table,
            replacement: '$table ',
            detail: 'Table',
          ),
        ),
      if (context.includeColumns)
        ..._flattenColumns(tableColumns).map(
          (column) => SqlSuggestion(
            kind: SqlSuggestionKind.column,
            value: column,
            replacement: '$column ',
            detail: 'Column',
          ),
        ),
    ];

    return _rankSuggestions(candidates, prefix);
  }

  TextRange currentTokenRange(String query, int cursorOffset) {
    final offset = cursorOffset.clamp(0, query.length);
    var start = offset;
    while (start > 0 && _isTokenChar(query[start - 1])) {
      start--;
    }

    var end = offset;
    while (end < query.length && _isTokenChar(query[end])) {
      end++;
    }

    return TextRange(start: start, end: end);
  }

  String applySuggestion({
    required String query,
    required int cursorOffset,
    required SqlSuggestion suggestion,
  }) {
    final range = currentTokenRange(query, cursorOffset);
    return query.replaceRange(range.start, range.end, suggestion.replacement);
  }

  int nextCursorOffset({
    required String query,
    required int cursorOffset,
    required SqlSuggestion suggestion,
  }) {
    final range = currentTokenRange(query, cursorOffset);
    return range.start + suggestion.replacement.length;
  }

  List<String> _flattenColumns(Map<String, List<String>> tableColumns) {
    final seen = <String>{};
    final flattened = <String>[];
    for (final columns in tableColumns.values) {
      for (final column in columns) {
        if (seen.add(column)) {
          flattened.add(column);
        }
      }
    }
    return flattened;
  }

  List<SqlSuggestion> _buildQualifiedColumnSuggestions(
    String prefix,
    Map<String, List<String>> tableColumns,
  ) {
    final parts = prefix.split('.');
    final tablePrefix = parts.first.toLowerCase();
    final columnPrefix = parts.length > 1 ? parts.last.toLowerCase() : '';
    final suggestions = <SqlSuggestion>[];

    for (final entry in tableColumns.entries) {
      if (!entry.key.toLowerCase().startsWith(tablePrefix)) continue;
      for (final column in entry.value) {
        if (columnPrefix.isNotEmpty &&
            !column.toLowerCase().startsWith(columnPrefix)) {
          continue;
        }
        suggestions.add(
          SqlSuggestion(
            kind: SqlSuggestionKind.column,
            value: '${entry.key}.$column',
            replacement: '${entry.key}.$column ',
            detail: entry.key,
          ),
        );
      }
    }

    return suggestions.take(8).toList();
  }

  List<SqlSuggestion> _rankSuggestions(
    List<SqlSuggestion> candidates,
    String prefix,
  ) {
    final loweredPrefix = prefix.toLowerCase();
    final unique = <String>{};
    final filtered = candidates.where((candidate) {
      final key = '${candidate.kind.name}:${candidate.value}';
      if (!unique.add(key)) return false;
      if (loweredPrefix.isEmpty) return true;
      return candidate.value.toLowerCase().contains(loweredPrefix);
    }).toList();

    filtered.sort((left, right) {
      final leftValue = left.value.toLowerCase();
      final rightValue = right.value.toLowerCase();
      final leftStarts = leftValue.startsWith(loweredPrefix);
      final rightStarts = rightValue.startsWith(loweredPrefix);
      if (leftStarts != rightStarts) {
        return leftStarts ? -1 : 1;
      }
      if (leftValue.length != rightValue.length) {
        return leftValue.length.compareTo(rightValue.length);
      }
      if (left.kind.index != right.kind.index) {
        return left.kind.index.compareTo(right.kind.index);
      }
      return leftValue.compareTo(rightValue);
    });

    return filtered.take(8).toList();
  }

  _SuggestionContext _detectContext(String beforeCursor, String prefix) {
    final normalized = beforeCursor.toUpperCase().trimRight();
    final tokens = RegExp(r'[A-Z_]+').allMatches(normalized).map((m) => m.group(0)!).toList();
    final previous = tokens.isNotEmpty ? tokens.last : '';
    final previousTwo = tokens.length >= 2
        ? '${tokens[tokens.length - 2]} ${tokens.last}'
        : previous;

    if (_matches(previous, const ['USE'])) {
      return const _SuggestionContext(databases: true);
    }

    if (_matches(previous, const ['FROM', 'JOIN', 'UPDATE', 'INTO', 'TABLE']) ||
        _matches(previousTwo, const ['DELETE FROM', 'INSERT INTO', 'ALTER TABLE', 'DROP TABLE'])) {
      return const _SuggestionContext(tables: true);
    }

    if (_matches(
      previous,
      const ['SELECT', 'WHERE', 'AND', 'OR', 'ON', 'SET', 'BY', 'HAVING'],
    ) ||
        _matches(previousTwo, const ['ORDER BY', 'GROUP BY'])) {
      return const _SuggestionContext(keywords: true, tables: true, columns: true);
    }

    if (prefix.isEmpty) {
      return const _SuggestionContext(
        keywords: true,
        databases: true,
        tables: true,
        columns: true,
      );
    }

    return const _SuggestionContext(
      keywords: true,
      databases: true,
      tables: true,
      columns: true,
    );
  }

  bool _matches(String value, List<String> expected) {
    return expected.contains(value);
  }

  bool _isTokenChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        char == '_' ||
        char == '.';
  }
}

class TextRange {
  final int start;
  final int end;

  const TextRange({required this.start, required this.end});
}

class _SuggestionContext {
  final bool includeKeywords;
  final bool includeDatabases;
  final bool includeTables;
  final bool includeColumns;

  const _SuggestionContext({
    bool keywords = false,
    bool databases = false,
    bool tables = false,
    bool columns = false,
  }) : includeKeywords = keywords,
       includeDatabases = databases,
       includeTables = tables,
       includeColumns = columns;
}
