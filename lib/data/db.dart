import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'cursor.dart';

class DbConn {
  static final int VERSION = 1;

  static Future<void> _runMigrations(Database db)  async{
    int currentVersion = db.select("PRAGMA user_version").first.values.first;
    currentVersion += 1;

    final commentPrefix = "--";
    final queryDelimiter = ";";

    final query = new StringBuffer();
    final queries = List.empty(growable: true);

    for (; currentVersion <= VERSION; currentVersion++) {
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
    return DbCursor.fromDbResult(res);
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

class DbCursor implements Cursor {
  int _position = -1;
  final List<List<Object?>> _rows;

  final Map<String, int> _columnsMap;

  static DbCursor fromDbResult(ResultSet res) {
    final columnsMap = HashMap<String, int>();
    res.columnNames.asMap().forEach((index, colName) {
      columnsMap[colName] = index;
    });

    return DbCursor(columnsMap, res.rows);
  }

  DbCursor(this._columnsMap, this._rows);

  bool moveToFirst() {
    return this.moveToPosition(0);
  }

  bool moveToLast() {
    return this.moveToPosition(this.count - 1);
  }

  bool moveToNext() {
    return this.move(1);
  }

  bool moveToPrev() {
    return this.move(-1);
  }

  bool moveToPosition(int index) {
    if (index >= 0 && index < this._rows.length) {
      this._position = index;
      return true;
    }
    return false;
  }

  int get count {
    return _rows.length;
  }

  bool move(int offset) {
    int idx = this._position + offset;
    if (idx > 0 && idx < this.count) {
      this._position = idx;
      return true;
    }
    return false;
  }

  T? getValue<T>({columnIndex: int, columnName: String}) {
    final valueIndex = columnIndex ?? this._columnsMap[columnName] ?? -1;
    if (valueIndex < 0 || valueIndex >= this._columnsMap.length) {
      return null;
    }

    if (this._position > -1 && this._position < this._rows.length) {
      final raw = this._rows[this._position][valueIndex];
      if (raw is T) {
        return raw;
      }
    }
    return null;
  }

  void dispose() {
    _rows.clear();
    _columnsMap.clear();
    _position = -1;
  }
}
