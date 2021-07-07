abstract class Cursor extends Iterable<Cursor> {
  int get count;
  int get dataVersion;
  Iterable<String> get columnNames;

  bool moveToFirst();

  bool moveToLast();

  bool moveToNext();

  bool moveToPrev();

  bool moveToPosition(int index);

  bool move(int position);

  T? getValue<T>({int? columnIndex, String? columnName});

  @override
  Iterator<Cursor> get iterator => _CursorIterator(this);
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
