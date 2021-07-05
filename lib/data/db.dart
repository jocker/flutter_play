import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'cursor.dart';
import 'matrix_cursor.dart';

class DbConn {
  static final int DB_VERSION = 1;

  static Future<void> _runMigrations(Database db) async {
    int currentVersion = db.select("PRAGMA user_version").first.values.first;
    currentVersion += 1;

    final commentPrefix = "--";
    final queryDelimiter = ";";

    final query = new StringBuffer();
    final queries = List.empty(growable: true);

    for (; currentVersion <= DB_VERSION; currentVersion++) {
      final sql = await rootBundle
          .loadString("assets/migrations/up.$currentVersion.sql");
      for (String line in LineSplitter.split(sql)) {
        line = line.trim();
        bool isEndOfQuery = line.endsWith(queryDelimiter);
        if (line.startsWith(commentPrefix)) {
          continue;
        }
        if (line.contains(commentPrefix)) {
          line = line.substring(0, line.indexOf(commentPrefix));
        }

        if (isEndOfQuery) {
          line = line.substring(0, line.length - queryDelimiter.length);
        }

        if (line.trim().length == 0) {
          continue;
        }

        query..write(" ")..write(line);
        if (isEndOfQuery) {
          queries.add(query.toString());
          query.clear();
        }
      }

      try {
        db.execute("begin transaction");
        for (var q in queries) {
          db.execute(q);
        }
        db.execute("PRAGMA user_version = $currentVersion");

        db.execute("commit");
      } catch (e) {
        db.execute("rollback");
        rethrow;
      }

      queries.clear();
      query.clear();
    }
  }

  static Future<DbConn> open(String fName) async {
    final fileName =
        path.join((await getApplicationDocumentsDirectory()).path, fName);
    final db = sqlite3.open(fileName);
    final conn = new DbConn(fileName, db);
    await _runMigrations(db);

    return conn;
  }

  final Database _db;
  final String _fileName;

  DbConn(this._fileName, this._db);

  Transaction transaction() {
    _db.execute("begin transaction");
    return Transaction(_fileName, _db);
  }

  void execute(String sql, [List<Object?> parameters = const []]) {
    _db.execute(sql, parameters);
  }

  PreparedStatement prepare(String sql) {
    return _db.prepare(sql, persistent: true);
  }

  Cursor select(String sql, [List<Object?> parameters = const []]) {
    final res = _db.select(sql, parameters);

    final columnsMap = HashMap<String, int>();
    res.columnNames.asMap().forEach((index, colName) {
      columnsMap[colName] = index;
    });

    return MatrixCursor(columnsMap, res.rows);
  }

  void dispose() {
    _db.dispose();
  }
}

class Transaction extends DbConn {
  Transaction(String filename, Database db) : super(filename, db);

  void rollback() {
    execute("rollback");
  }

  void commit() {
    execute("commit");
  }
}
