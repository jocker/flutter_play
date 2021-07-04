import 'dart:collection';

import 'package:get/get.dart';
import 'package:sqlite3/sqlite3.dart';

void checkDb() {
  final db = sqlite3.open("aa.db");
  db.execute("begin transaction");
  db.execute("close transaction");
}

class DbConn {
  final Database _db;

  DbConn(this._db);

  Transaction transaction() {
    _db.execute("begin transaction");
    return Transaction(_db);
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
  Transaction(Database db) : super(db);

  void rollback() {
    execute("rollback");
  }

  void commit() {
    execute("commit");
  }
}

abstract class Cursor {
  int get count;

  bool moveToFirst();

  bool moveToLast();

  bool moveToNext();

  bool moveToPrev();

  bool moveToPosition(int index);

  bool move(int position);

  T? getValue<T>({columnIndex: int, columnName: String});
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
