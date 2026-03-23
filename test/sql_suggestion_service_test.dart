import 'package:flutter_test/flutter_test.dart';
import 'package:term_ssh/services/sql_suggestion_service.dart';

void main() {
  final service = SqlSuggestionService();

  test('suggests tables after FROM', () {
    final suggestions = service.buildSuggestions(
      query: 'SELECT * FROM us',
      cursorOffset: 'SELECT * FROM us'.length,
      databases: const ['ssh_sync_db'],
      tables: const ['users', 'user_logs', 'orders'],
      tableColumns: const {
        'users': ['id', 'email'],
      },
    );

    expect(suggestions.first.value, 'users');
    expect(suggestions.any((item) => item.kind == SqlSuggestionKind.table), isTrue);
  });

  test('suggests databases after USE', () {
    final suggestions = service.buildSuggestions(
      query: 'USE tr',
      cursorOffset: 'USE tr'.length,
      databases: const ['track_myads', 'ssh_sync_db'],
      tables: const [],
      tableColumns: const {},
    );

    expect(suggestions.first.value, 'track_myads');
  });

  test('suggests qualified columns for table prefix', () {
    final suggestions = service.buildSuggestions(
      query: 'SELECT users.',
      cursorOffset: 'SELECT users.'.length,
      databases: const [],
      tables: const ['users'],
      tableColumns: const {
        'users': ['id', 'email'],
      },
    );

    expect(suggestions.map((item) => item.value), containsAll(['users.id', 'users.email']));
  });
}
