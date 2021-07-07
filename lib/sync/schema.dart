import 'package:vgbnd/models/base_model.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/sync/value_holder.dart';

class SchemaVersion {
  String schemaName;
  int revNum;

  SchemaVersion(this.schemaName, this.revNum);
}

class SyncDbColumn<T> {
  static SyncDbColumn<T> id<T extends BaseModel>() {
    return SyncDbColumn<T>(
      "id",
      readAttribute: (dest) => dest.id,
      assignAttribute: (value, key, dest) {
        dest.id = value.getValue<int>(key) ?? dest.id;
      },
    );
  }

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

class SyncDbSchema<T> {
  static int parseRevNum(String raw) {
    var revNum = DateTime.tryParse(raw + 'Z');
    if (revNum == null) {
      revNum = DateTime.tryParse(raw);
    }

    return revNum?.millisecondsSinceEpoch ?? 0;
  }

  static SyncDbSchema<dynamic>? byNameStrict(String name) {
    final schema = byName(name);
    if (schema == null) {
      throw Exception("unknown schema $name");
    }
    return schema;
  }

  static bool isRegisteredSchema(String name) {
    return byName(name) != null;
  }

  static SyncDbSchema<dynamic>? byName(String name) {
    switch (name) {
      case Coil.SCHEMA_NAME:
        return Coil.schema;
      case Location.SCHEMA_NAME:
        return Location.schema;
      case Product.SCHEMA_NAME:
        return Product.schema;
    }

    return null;
  }

  String schemaName;
  late String tableName;
  List<SyncDbColumn<T>> columns;
  T Function() allocate;

  SyncDbSchema(this.schemaName, {required this.columns, required this.allocate, String? tableName}) {
    this.tableName = tableName ?? this.schemaName;
  }

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
    return columns.where((element) => element.syncOps.contains(SyncDbRemoteOp.Read)).toList(growable: false);
  }

  List<SyncDbColumn<T>> get remoteWriteableColumns {
    return columns.where((element) => element.syncOps.contains(SyncDbRemoteOp.Write)).toList(growable: false);
  }

  T createObject(Map<String, dynamic>? values) {
    T instance = allocate();
    if (values != null) {
      final m = PrimitiveValueHolder.fromMap(values);
      for (var col in columns) {
        col.assignAttribute(m, col.name, instance);
      }
    }
    return instance;
  }

  PrimitiveValueHolder dumpObject(T instance) {
    final m = PrimitiveValueHolder.empty();
    for (var col in columns) {
      m.putValue(col.name, col.readAttribute(instance));
    }
    return m;
  }
}
