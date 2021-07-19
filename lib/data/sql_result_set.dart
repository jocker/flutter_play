

class SqlResultSet extends Iterable<SqlRow> {
  final List<String> columnNames;
  late final Map<String, int> _calculatedIndexes;
  late final int _maxColumnIndex;

  final List<List<Object?>> rows;

  static SqlResultSet fromJson(Map<String, dynamic> json) {
    return SqlResultSet(json["column_names"], json["rows"]);
  }

  SqlResultSet(this.columnNames, this.rows) {
    _calculatedIndexes = {
      for (var column in columnNames) column: columnNames.lastIndexOf(column),
    };
    _maxColumnIndex = this.columnNames.length;
  }

  @override
  Iterator<SqlRow> get iterator => _ResultIterator(this);

  Map<String, dynamic> toJson() {
    return {
      "column_names": this.columnNames,
      "rows": this.rows,
    };
  }

  int get size {
    return rows.length;
  }
}

class SqlRow {
  final SqlResultSet _result;
  final int _rowIndex;

  SqlRow._(this._result, this._rowIndex);

  dynamic getValueAt({String? columnName, int? columnIndex}) {
    int valueIndex = columnIndex ?? _result._calculatedIndexes[columnName ?? ""] ?? -1;
    if (valueIndex < 0 || valueIndex >= _result._maxColumnIndex) {
      return null;
    }

    return _result.rows[_rowIndex][valueIndex];
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> res = {};
    for (final col in _result.columnNames) {
      res[col] = getValueAt(columnName: col);
    }

    return res;
  }
}

class _ResultIterator extends Iterator<SqlRow> {
  final SqlResultSet result;
  int index = -1;

  _ResultIterator(this.result);

  @override
  SqlRow get current => SqlRow._(result, index);

  @override
  bool moveNext() {
    index++;
    return index < result.rows.length;
  }
}
