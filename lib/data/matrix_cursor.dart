import 'package:vgbnd/ext.dart';

import 'cursor.dart';

class MatrixCursor extends Cursor {
  int _cursorPos = -1;
  List<String>? _columnNames;
  final List<List<Object?>> _rows;

  final Map<String, int> _columnsMap;

  static MatrixCursor fromJson(Map<String, dynamic> json) {
    return MatrixCursor(json["columns_map"], json["rows"]);
  }

  List<String> get columnNames {
    if (_columnNames == null) {
      final cols = List.of(_columnsMap.keys);
      cols.sort((a, b) => _columnsMap[a]!.compareTo(_columnsMap[b]!));
      _columnNames = cols;
    }
    return _columnNames!;
  }

  MatrixCursor(this._columnsMap, this._rows) {
    _cursorPos = -1;
  }

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

  bool moveToPosition(int pos) {
    if (pos == this._cursorPos) {
      return true;
    }
    if (pos >= 0 && pos < this._rows.length) {
      this._cursorPos = pos;
      return true;
    }
    return false;
  }

  int get count {
    return _rows.length;
  }

  bool move(int offset) {
    int idx = this._cursorPos + offset;
    if (idx >= 0 && idx < this.count) {
      this._cursorPos = idx;
      return true;
    }
    return false;
  }

  T? getValue<T>({int? columnIndex, String? columnName}) {
    final valueIndex = columnIndex ?? this._columnsMap[columnName] ?? -1;
    if (valueIndex < 0 || valueIndex >= this._columnsMap.length) {
      return null;
    }

    if (this._cursorPos > -1 && this._cursorPos < this._rows.length) {
      final raw = this._rows[this._cursorPos][valueIndex];
      return readPrimitive(raw);
    }
    return null;
  }

  void dispose() {
    _rows.clear();
    _columnsMap.clear();
    _cursorPos = -1;
  }

  @override
  int get dataVersion => 0;

  Map<String, dynamic> toJson() {
    return {
      "columns_map": _columnsMap,
      "rows": _rows,
    };
  }

  @override
  int get position => _cursorPos;
}
