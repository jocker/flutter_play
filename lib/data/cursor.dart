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