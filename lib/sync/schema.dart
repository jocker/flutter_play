import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/value_holder.dart';

class SchemaVersion {
  String schemaName;
  int revNum;

  SchemaVersion(this.schemaName, this.revNum);
}

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
}
