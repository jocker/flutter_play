import 'dart:collection';

import '../ext.dart';

// should contain only primitive values which can be directly used with sqlite3
// For now, boolean values are going to be mapped to 1 or 0
// datetime values are going to be stringified

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

  PrimitiveValueHolder diffFrom(PrimitiveValueHolder other) {
    final myValues = this.toMap();
    final otherValues = other.toMap();

    final keys = Set<String>()..addAll(myValues.keys)..addAll(otherValues.keys);

    Map<String, dynamic> diff = {};
    for (var key in keys) {
      if (myValues[key] != otherValues[key]) {
        diff[key] = otherValues[key];
      }
    }

    return PrimitiveValueHolder.fromMap(diff);
  }
}

class _MapValueHolder extends PrimitiveValueHolder {
  Map<String, dynamic> _values;

  _MapValueHolder(this._values);

  T? getValue<T>(String key) {
    if (_values.containsKey(key)) {
      return readPrimitive<T>(_values[key]);
    }
    return null;
  }

  @override
  putValue(String key, dynamic value) {
    if (value is DateTime) {
      value = value.toIso8601String();
    }
    if (value is bool) {
      value = value == true ? 1 : 0;
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
