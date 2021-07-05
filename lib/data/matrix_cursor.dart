import 'cursor.dart';

class MatrixCursor implements Cursor {
  int _position = -1;
  final List<List<Object?>> _rows;

  final Map<String, int> _columnsMap;

  MatrixCursor(this._columnsMap, this._rows);

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