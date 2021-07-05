import 'dart:collection';

class SyncDbColumn<T> {
  String name;
  Function(PrimitiveValueHolder value, String key, T dest) assignAttribute;
  dynamic Function(T dest) readAttribute;
  List<SyncDbRemoteOp> syncOps;

  SyncDbColumn(this.name,
      {required this.assignAttribute,
      required this.readAttribute,
      this.syncOps = const [SyncDbRemoteOp.Read, SyncDbRemoteOp.Write]});

  assign() {}
}

enum SyncDbRemoteOp { Read, Write }

class SyncDbCollection<T> {
  String name;
  List<SyncDbColumn<T>> columns;
  T Function() allocate;

  SyncDbCollection(this.name, {required this.columns, required this.allocate});

  PrimitiveValueHolder getValues(T obj) {
    var holder = PrimitiveValueHolder.empty();
    columns.forEach((col) {
      var v = col.readAttribute(obj);
      if (v != null) {
        holder.putNonNull(col.name, v);
      }
    });
    return holder;
  }

  List<SyncDbColumn<T>> get remoteReadableColumns {
    return columns
        .where((element) => element.syncOps.contains(SyncDbRemoteOp.Read))
        .toList(growable: false);
  }

  List<SyncDbColumn<T>> get remoteWriteableColumns {
    return columns
        .where((element) => element.syncOps.contains(SyncDbRemoteOp.Write))
        .toList(growable: false);
  }
}

class Coil extends BaseModel {
  static const String TABLE_NAME = 'columns';

  static final schema =
      SyncDbCollection<Coil>("columns", allocate: () => Coil(), columns: [
    SyncDbColumn<Coil>(
      "id",
      readAttribute: (dest) => dest.id,
      assignAttribute: (value, key, dest) {
        dest.id = value.getValue(key) ?? dest.id;
      },
    ),
    SyncDbColumn(
      "column_name",
      readAttribute: (dest) => dest.columnName,
      assignAttribute: (value, key, dest) {
        dest.columnName = value.getValue(key) ?? dest.columnName;
      },
    ),
    SyncDbColumn(
      "planogram_id",
      readAttribute: (dest) => dest.planogramId,
      assignAttribute: (value, key, dest) {
        dest.planogramId = value.getValue(key) ?? dest.planogramId;
      },
    ),
    SyncDbColumn(
      "product_id",
      readAttribute: (dest) => dest.productId,
      assignAttribute: (value, key, dest) {
        dest.productId = value.getValue(key) ?? dest.productId;
      },
    ),
    SyncDbColumn(
      "location_id",
      readAttribute: (dest) => dest.locationId,
      assignAttribute: (value, key, dest) {
        dest.locationId = value.getValue(key) ?? dest.locationId;
      },
    ),
    SyncDbColumn(
      "display_name",
      readAttribute: (dest) => dest.displayName,
      assignAttribute: (value, key, dest) {
        dest.displayName = value.getValue(key) ?? dest.displayName;
      },
    ),
    SyncDbColumn(
      "last_fill",
      readAttribute: (dest) => dest.lastFill,
      assignAttribute: (value, key, dest) {
        dest.lastFill = value.getValue(key) ?? dest.lastFill;
      },
    ),
    SyncDbColumn(
      "capacity",
      readAttribute: (dest) => dest.capacity,
      assignAttribute: (value, key, dest) {
        dest.capacity = value.getValue(key) ?? dest.capacity;
      },
    ),
    SyncDbColumn(
      "max_capacity",
      readAttribute: (dest) => dest.maxCapacity,
      assignAttribute: (value, key, dest) {
        dest.maxCapacity = value.getValue(key) ?? dest.maxCapacity;
      },
    ),
    SyncDbColumn(
      "last_visit",
      readAttribute: (dest) => dest.lastVisit,
      assignAttribute: (value, key, dest) {
        dest.lastVisit = value.getValue(key) ?? dest.lastVisit;
      },
    ),
    SyncDbColumn(
      "tray_id",
      readAttribute: (dest) => dest.trayId,
      assignAttribute: (value, key, dest) {
        dest.trayId = value.getValue(key) ?? dest.trayId;
      },
    ),
    SyncDbColumn(
      "coil_notes",
      readAttribute: (dest) => dest.coilNotes,
      assignAttribute: (value, key, dest) {
        dest.coilNotes = value.getValue(key) ?? dest.coilNotes;
      },
    ),
    SyncDbColumn(
      "set_price",
      readAttribute: (dest) => dest.setPrice,
      assignAttribute: (value, key, dest) {
        dest.setPrice = value.getValue(key) ?? dest.setPrice;
      },
    ),
    SyncDbColumn(
      "sts_coils",
      readAttribute: (dest) => dest.stsCoils,
      assignAttribute: (value, key, dest) {
        dest.stsCoils = value.getValue(key) ?? dest.stsCoils;
      },
    ),
    SyncDbColumn(
      "active",
      readAttribute: (dest) => dest.active,
      assignAttribute: (value, key, dest) {
        dest.active = value.getValue(key) ?? dest.active;
      },
    ),
  ]);

  String? columnName;
  int? planogramId;
  int? productId;
  int? locationId;
  String? displayName;
  int? lastFill;
  int? capacity;
  int? maxCapacity;
  DateTime? lastVisit;
  int? trayId;
  String? coilNotes;
  int? setPrice;
  String? stsCoils;
  bool? active;
}

abstract class BaseModel<T> {
  int? id;

  bool isNewRecord() {
    return this.id == null;
  }
}

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
