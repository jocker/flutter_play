T? readPrimitive<T>(dynamic v) {
  if (v is T) {
    return v;
  }
  if (T == DateTime) {
    var raw = readPrimitive<String>(v);
    if (raw != null) {
      return DateTime.tryParse(raw) as T?;
    }
  }
  if(T == bool){
    var intBool = readPrimitive<int>(v);
    if(intBool != null){
      return (intBool == 1) as T;
    }
  }

  return null;
}
