
import 'dart:collection';

abstract class PrimitiveValueHolder {
  static PrimitiveValueHolder empty() {
    return fromMap(HashMap());
  }

  static PrimitiveValueHolder fromMap(Map<String, dynamic> values) {
    return _MapValueHolder(Map.from(values));
  }

  T? getValue<T>(String key);

  putValue(String key, dynamic value);

  Map<String, dynamic> toMap();

  putNonNull(String key, dynamic value);

  clear();
}

class _MapValueHolder extends PrimitiveValueHolder {
  Map<String, dynamic> _values;

  _MapValueHolder(this._values);

  T? getValue<T>(String key) {
    if (_values.containsKey(key)) {
      var v = _values[key];
      if (v is T) {
        return v;
      }
      if (T is DateTime) {
        var raw = getValue<String>(key);
        if (raw != null) {
          return DateTime.tryParse(raw) as T?;
        }
      }
    }
    return null;
  }

  @override
  putValue(String key, dynamic value) {
    if (value is DateTime) {
      value = value.toIso8601String();
    }
    _values[key] = value;
  }

  @override
  Map<String, dynamic> toMap() {
    return Map.from(_values);
  }

  @override
  clear() {
    _values.clear();
  }

  @override
  putNonNull(String key, dynamic value) {
    if (value != null) {
      putValue(key, value);
    }
  }
}