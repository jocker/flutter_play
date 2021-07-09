import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/ext.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/models/machine_column_sales.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/models/productlocation.dart';
import 'package:vgbnd/sync/constants.dart';
import 'package:vgbnd/sync/value_holder.dart';

typedef SchemaName = String;

class SchemaVersion {
  SchemaName schemaName;
  int revNum;

  SchemaVersion(this.schemaName, this.revNum);
}

class SyncDbColumn<T> {
  static SyncDbColumn<T> readonly<T extends SyncObject>(String colName, {SchemaName? referenceOf}) {
    return SyncDbColumn<T>(
      "id",
      readAttribute: (dest) => throw UnsupportedError("unsupported"),
      assignAttribute: (value, key, dest) {
        throw UnsupportedError("unsupported");
      },
    );
  }

  static SyncDbColumn<T> id<T extends SyncObject>() {
    return SyncDbColumn<T>(
      "id",
      readAttribute: (dest) => dest.id,
      assignAttribute: (value, key, dest) {
        dest.id = value.getValue<int>(key) ?? dest.id;
      },
    );
  }

  String name;
  SchemaName? referenceOf;
  Function(PrimitiveValueHolder value, String key, T dest) assignAttribute;
  dynamic Function(T dest) readAttribute;
  List<SyncSchemaOp> syncOps;

  SyncDbColumn(this.name,
      {required this.assignAttribute,
      required this.readAttribute,
      this.syncOps = const [SyncSchemaOp.RemoteRead, SyncSchemaOp.RemoteWrite],
      this.referenceOf});

  assign() {}
}

class SyncDbSchema<T> {
  static int? parseRevNum(String raw) {
    var revNum = DateTime.tryParse(raw + 'Z');
    if (revNum == null) {
      revNum = DateTime.tryParse(raw);
    }

    return revNum?.millisecondsSinceEpoch;
  }

  bool get remoteReadable {
    return this.syncOps.contains(SyncSchemaOp.RemoteRead);
  }

  bool get remoteWritable {
    return this.syncOps.contains(SyncSchemaOp.RemoteWrite);
  }

  SyncDbColumn<T>? get idColumn {
    return columns.firstWhereOrNull((col) => col.name == "id");
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
      case ProductLocation.SCHEMA_NAME:
        return ProductLocation.schema;
      case MachineColumnSale.SCHEMA_NAME:
        return MachineColumnSale.schema;
    }

    return null;
  }

  SchemaName schemaName;
  late String tableName;
  List<SyncDbColumn<T>> columns;
  T Function() allocate;
  late final List<SyncSchemaOp> syncOps;

  SyncDbSchema(this.schemaName,
      {required this.columns, required this.allocate, String? tableName, List<SyncSchemaOp>? syncOps}) {
    this.tableName = tableName ?? this.schemaName;
    this.syncOps = syncOps ?? [SyncSchemaOp.RemoteRead, SyncSchemaOp.RemoteWrite];
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
    return columns.where((element) => element.syncOps.contains(SyncSchemaOp.RemoteRead)).toList(growable: false);
  }

  List<SyncDbColumn<T>> get remoteWriteableColumns {
    return columns.where((element) => element.syncOps.contains(SyncSchemaOp.RemoteWrite)).toList(growable: false);
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

  onChangesetApplied(RemoteSchemaChangeset changeset, Transaction tx) {
    // any cleanup that should happen after the changeset data is saved in the db
    // this should be a quick operation as we don't want to keep the database locked for a long period of time
  }
}
