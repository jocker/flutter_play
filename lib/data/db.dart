import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vgbnd/data/sql_result_set.dart';

class DbConn {
  static final int DB_VERSION = 1;

  static String sqlIn(List items) {
    final List<String> strList = List.filled(items.length, "null");
    items.asMap().forEach((key, value) {
      late String strValue;
      if (value == null) {
        strValue = 'null';
      } else if (value is int || value is double) {
        strValue = value.toString();
      } else {
        strValue = "'$value'";
      }
      strList[key] = strValue;
    });

    return " ( ${strList.join(", ")} ) ";
  }

  static Future<void> _runMigrations(Database db) async {
    int currentVersion = db.userVersion;
    currentVersion += 1;

    final commentPrefix = "--";
    final queryDelimiter = ";";

    final query = new StringBuffer();
    final queries = List.empty(growable: true);

    for (; currentVersion <= DB_VERSION; currentVersion++) {
      final sql = await rootBundle.loadString("assets/migrations/up.$currentVersion.sql");
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
        db.userVersion = currentVersion;

        db.execute("commit");
      } catch (e) {
        db.execute("rollback");
        rethrow;
      }

      queries.clear();
      query.clear();
    }
  }

  // needs to run in the main isolate
  static Future<void> runMigrations(String dbPath) async {
    final db = await DbConn.open(dbPath, runMigrations: true);
    db.dispose();
  }

  static Future<DbConn> open(String absoluteDbPath, {bool? runMigrations}) async {
    final db = sqlite3.open(absoluteDbPath);
    final conn = new DbConn(absoluteDbPath, db);
    if (runMigrations != false) {
      await _runMigrations(db);
    }
    return conn;
  }

  Database _db;
  final String _fileName;

  DbConn(this._fileName, this._db);

  Transaction transaction() {
    execute("begin transaction");
    return Transaction(_fileName, _db);
  }

  bool inTransaction() {
    return this is Transaction;
  }

  runInTransaction(bool Function(Transaction tx) fn) {
    final tx = transaction();
    try {
      if (fn(tx)) {
        tx.commit();
      } else {
        tx.rollback();
      }
    } catch (e) {
      rethrow;
    } finally {
      if (!tx._isDone) {
        tx.rollback();
      }
    }
  }

  void execute(String sql, [List<Object?> parameters = const []]) {
    _db.execute(sql, parameters);
  }

  PreparedStatement prepare(String sql) {
    return _db.prepare(sql, persistent: true);
  }

  int get affectedRowsCount {
    return _db.getUpdatedRows();
  }

  int get lastInsertRowId {
    return _db.lastInsertRowId;
  }

  SqlResultSet select(String sql, [List<Object?> parameters = const []]) {
    final res = _db.select(sql, parameters);
    return SqlResultSet(res.columnNames, res.rows);
  }

  Map<String, dynamic>? selectOne(String sql, [List<Object?> parameters = const []]) {
    final c = select(sql, parameters);
    if (c.size == 1) {
      return c.first.toMap();
    }
    return null;
  }

  T? selectValue<T>(String sql, [List<Object?> parameters = const []]) {
    final c = select(sql, parameters);

    if (c.size == 1) {
      if (c.columnNames.length == 1) {
        return c.first.getValueAt(columnName: c.columnNames.first);
      }
    }

    return null;
  }

  void dispose() {
    _db.dispose();
  }

  reconnect() {
    _db.dispose();
    _db = sqlite3.open(_fileName);
  }

  void upsert(String tableName, Map<String, dynamic> pkValues, Map<String, dynamic> values) {
    update(tableName, values, pkValues);
    if (this.affectedRowsCount == 0) {
      final merged = Map.of(pkValues)..addAll(values);
      insert(tableName, merged);
    }
  }

  void update(String tableName, Map<String, dynamic> updateValues, [Map<String, dynamic>? whereArgs]) {
    List args = [];
    final query = StringBuffer("update $tableName set ");
    _appendToQuery(query, updateValues, ", ", args);
    if ((whereArgs?.length ?? 0) > 0) {
      query.write(" where ");
      _appendToQuery(query, whereArgs!, " and ", args);
    }

    execute(query.toString(), args);
  }

  void insert(String tableName, Map<String, dynamic> values, {OnConflictDo? onConflict}) {
    List args = [];
    List<String> colNames = [];

    values.forEach((key, value) {
      args.add(value);
      colNames.add(key);
    });

    final query = StringBuffer("insert");
    switch (onConflict ?? OnConflictDo.Fail) {
      case OnConflictDo.Ignore:
        query.write(" or ignore ");
        break;
      case OnConflictDo.Replace:
        query.write(" or replace ");
        break;
      case OnConflictDo.Fail:
      default:
        break;
    }
    query
      ..write(" into ")
      ..write(tableName)
      ..write("(")
      ..write(colNames.join(","))
      ..write(")")
      ..write(" values(")
      ..write(List.filled(values.length, "?").join(", "))
      ..write(")");

    execute(query.toString(), args);
  }

  _appendToQuery(StringBuffer query, Map<String, dynamic> params, String paramDelim, List<dynamic> queryParams) {
    int idx = 0;
    params.forEach((key, value) {
      if (idx > 0) {
        query.write(paramDelim);
      }
      query..write(key)..write("=?");
      queryParams.add(value);
      idx += 1;
    });
  }
}

class Transaction extends DbConn {
  Transaction(String filename, Database db) : super(filename, db);
  bool _isDone = false;

  void rollback() {
    _finalizeWith("rollback");
  }

  void commit() {
    _finalizeWith("commit");
  }

  _finalizeWith(String sql) {
    if (!_isDone) {
      _isDone = true;
      execute(sql);
    }
  }
}

class DbResult {
  final int affectedCount;
  final int lastInsertId;

  DbResult(this.affectedCount, this.lastInsertId);
}

enum OnConflictDo { Fail, Ignore, Replace }
