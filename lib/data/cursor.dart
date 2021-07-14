abstract class Cursor {
  int get count;

  int get dataVersion;

  int get position;

  Iterable<String> get columnNames;

  bool moveToFirst();

  bool moveToLast();

  bool moveToNext();

  bool moveToPrev();

  bool moveToPosition(int index);

  bool move(int position);

  T? getValue<T>({int? columnIndex, String? columnName});

  Iterable<Cursor> asIterable() => _CursorIterable(this);
}

class _CursorIterable extends Iterable<Cursor> {
  final Cursor _cursor;

  _CursorIterable(this._cursor);

  @override
  Iterator<Cursor> get iterator => _CursorIterator(_cursor);
}

class _CursorIterator extends Iterator<Cursor> {
  final Cursor _cursor;
  bool _movedToFirst = false;

  _CursorIterator(this._cursor);

  @override
  Cursor get current => this._cursor;

  @override
  bool moveNext() {
    if (!_movedToFirst) {
      _movedToFirst = true;
      return this._cursor.moveToFirst();
    }
    return this._cursor.moveToNext();
  }
}
