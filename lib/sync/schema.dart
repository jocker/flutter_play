import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/ext.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/models/machine_column_sales.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/pack_entry.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/models/productlocation.dart';
import 'package:vgbnd/models/restock.dart';
import 'package:vgbnd/models/restock_entry.dart';
import 'package:vgbnd/sync/mutation/default_remote_mutation_handler.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/value_holder.dart';

import 'mutation/mutation_handlers.dart';

typedef SchemaName = String;

class SchemaVersion {
  SchemaName schemaName;
  int revNum;

  SchemaVersion(this.schemaName, this.revNum);
}

class SyncColumn<T> {
  static SyncColumn<T> readonly<T>(String colName, {ReferenceOfSchema? referenceOf}) {
    return SyncColumn<T>(
      colName,
      referenceOf: referenceOf,
      readAttribute: (dest) => throw UnsupportedError("unsupported"),
      assignAttribute: (value, key, dest) {
        throw UnsupportedError("unsupported");
      },
    );
  }

  static SyncColumn<T> id<T extends SyncObject<T>>() {
    return SyncColumn<T>(
      "id",
      readAttribute: (dest) => dest.id,
      assignAttribute: (value, key, dest) {
        dest.id = value.getValue<int>(key) ?? dest.id;
      },
    );
  }

  String name;

  /// this column is a foreign key to another table.
  /// Will be updated whenever the primary key of the table it references gets updated
  /// Will be deleted whenever the the record it references gets deleted
  ReferenceOfSchema? referenceOf;
  Function(PrimitiveValueHolder value, String key, T dest) assignAttribute;
  dynamic Function(T dest) readAttribute;

  List<SyncSchemaOp> syncOps;

  late final bool isDisplayNameColumn;

  SyncColumn(this.name,
      {required this.assignAttribute,
      required this.readAttribute,
      this.syncOps = const [SyncSchemaOp.RemoteRead, SyncSchemaOp.RemoteWrite],
      this.referenceOf,
      bool? isDisplayNameColumn}) {
    this.isDisplayNameColumn = isDisplayNameColumn ?? false;
  }

  writeValue(T dest, Object value) {
    assignAttribute(PrimitiveValueHolder.fromMap({this.name: value}), this.name, dest);
  }
}

class SyncSchema<T extends SyncObject<T>> {
  static const REMOTE_COL_REVISION_DATE = "updated_at";
  static const REMOTE_COL_DELETED = "deleted";
  static const REMOTE_COL_ID = "id";

  static int? parseRevNum(String? raw) {
    if (raw == null) {
      return null;
    }
    var revNum = DateTime.tryParse(raw + 'Z');
    if ((revNum?.millisecondsSinceEpoch ?? 0) == 0) {
      revNum = DateTime.tryParse(raw);
    }

    if ((revNum?.millisecondsSinceEpoch ?? 0) == 0) {
      revNum = null;
    }

    return revNum?.millisecondsSinceEpoch;
  }

  bool get remoteReadable {
    return this.syncOps.contains(SyncSchemaOp.RemoteRead);
  }

  bool get remoteWritable {
    return this.syncOps.contains(SyncSchemaOp.RemoteWrite);
  }

  SyncColumn<T>? get idColumn {
    return getColumnByName("id");
  }

  SyncColumn<T>? getColumnByName(String name) {
    return columns.firstWhereOrNull((col) => col.name == name);
  }

  static SyncSchema<dynamic> byNameStrict(String name) {
    final schema = byName(name);
    if (schema == null) {
      throw Exception("unknown schema $name");
    }
    return schema;
  }

  static bool isRegisteredSchema(String name) {
    return byName(name) != null;
  }

  static SyncSchema<dynamic>? byName(String name) {
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
      case Pack.SCHEMA_NAME:
        return Pack.schema;
      case PackEntry.SCHEMA_NAME:
        return PackEntry.schema;
      case Restock.SCHEMA_NAME:
        return Restock.schema;
      case RestockEntry.SCHEMA_NAME:
        return RestockEntry.schema;
    }

    return null;
  }

  SchemaName schemaName;
  late String tableName;
  List<SyncColumn<T>> columns;
  T Function() allocate;
  late final List<SyncSchemaOp> syncOps;

  late final LocalMutationHandler<T> localMutationHandler;
  late final RemoteMutationHandler<T> remoteMutationHandler;

  SyncSchema(this.schemaName,
      {required this.columns,
      required this.allocate,
      String? tableName,
      List<SyncSchemaOp>? syncOps,
      LocalMutationHandler<T>? localMutationHandler,
      RemoteMutationHandler<T>? remoteMutationHandler}) {
    this.tableName = tableName ?? this.schemaName;
    this.syncOps = syncOps ?? [SyncSchemaOp.RemoteRead, SyncSchemaOp.RemoteWrite];
    this.localMutationHandler = localMutationHandler ?? LocalMutationHandler.basic();
    this.remoteMutationHandler = remoteMutationHandler ?? DefaultRemoteMutationHandler<T>();
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

  List<SyncColumn<T>> get remoteReadableColumns {
    return columns.where((element) => element.syncOps.contains(SyncSchemaOp.RemoteRead)).toList(growable: false);
  }

  List<SyncColumn<T>> get remoteWriteableColumns {
    return columns.where((element) => element.syncOps.contains(SyncSchemaOp.RemoteWrite)).toList(growable: false);
  }

  List<SyncColumn<T>> get remoteReferenceColumns {
    return remoteWriteableColumns.where((col) => col.referenceOf != null).toList(growable: false);
  }

  T instantiate(Map<String, dynamic>? values) {
    T instance = allocate();
    instance.assignValues(values);
    return instance;
  }

  assignValues(T instance, Map<String, dynamic>? values) {
    if (values != null) {
      final m = PrimitiveValueHolder.fromMap(values);
      for (var col in columns) {
        col.assignAttribute(m, col.name, instance);
      }
    }
  }

  PrimitiveValueHolder dumpObject(T instance) {
    final m = PrimitiveValueHolder.empty();
    for (var col in columns) {
      m.putValue(col.name, col.readAttribute(instance));
    }
    return m;
  }
}

class ReferenceOfSchema {
  final String schemaName;
  late final onDeleteReferenceDo;

  ReferenceOfSchema(this.schemaName, {OnDeleteReferenceDo? onDeleteReferenceDo}) {
    this.onDeleteReferenceDo = onDeleteReferenceDo ?? OnDeleteReferenceDo.Nothing;
  }
}

enum OnDeleteReferenceDo { Nothing, Delete }
