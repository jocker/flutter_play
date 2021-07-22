import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/log.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/value_holder.dart';

class SyncPendingRemoteMutation {
  static const TABLE_NAME = "_sync_pending_remote_mutations";

  static const STATUS_NONE = 0, STATUS_PENDING = 1, STATUS_SUCCESS = 2, STATUS_FAILURE = 3;

  static SyncPendingRemoteMutation? loadForObject(SyncObject obj, DbConn conn) {
    final dbValues = conn.selectOne(
        "select * from ${SyncPendingRemoteMutation.TABLE_NAME} where schema_name=? and object_id=?",
        [obj.getSchema().schemaName, obj.getId()]);

    if (dbValues != null) {
      return SyncPendingRemoteMutation.fromDbValues(dbValues);
    }
    return null;
  }

  static SyncPendingRemoteMutation fromModel(SyncObject instance, SyncObjectMutationType op) {
    return SyncPendingRemoteMutation(
        schemaName: instance.getSchema().schemaName,
        objectId: instance.id ?? 0,
        mutationType: op,
        ts: DateTime.now().millisecondsSinceEpoch);
  }

  static SyncPendingRemoteMutation? fromJson(Map<String, dynamic> json) {
    if (json["data"] is String) {
      json["data"] = jsonDecode(json["data"]);
    }
    return SyncPendingRemoteMutation(
        schemaName: json["schema_name"],
        objectId: json["object_id"],
        mutationType: SyncObjectMutationType.values[json["mutation_type"]],
        data: json["data"],
        ts: json["ts"]);
  }

  static SyncPendingRemoteMutation? fromDbValues(Map<String, dynamic> dbValues) {
    final c = PrimitiveValueHolder.fromMap(dbValues);
    final rawUUid = c.getValue<String>("uuid");
    if (rawUUid == null) {
      return null;
    }
    final rawSchemaName = c.getValue<String>("schema_name");
    if (rawSchemaName == null) {
      return null;
    }

    final rawObjectId = c.getValue<int>("object_id");
    final rawOp = c.getValue<int>("mutation_type");
    final rawRevNum = c.getValue<int>("rev_num");
    final rawTs = c.getValue<int>("ts");

    if (rawObjectId == null || rawOp == null || rawRevNum == null || rawTs == null) {
      return null;
    }

    SyncObjectMutationType? op;
    if (rawOp >= 0 && rawOp < SyncObjectMutationType.values.length) {
      op = SyncObjectMutationType.values[rawOp];
    }

    if (op == null) {
      return null;
    }

    final rec =
        SyncPendingRemoteMutation(schemaName: rawSchemaName, objectId: rawObjectId, mutationType: op, ts: rawTs);

    final rawData = c.getValue<String>("data");
    if (rawData != null) {
      try {
        rec.data = jsonDecode(rawData);
      } catch (e) {
        logger.e("error decoding json", e);
      }
    }

    return rec;
  }

  SyncPendingRemoteMutation(
      {required this.schemaName, required this.objectId, required this.mutationType, this.data, required this.ts});

  SchemaName schemaName;
  int objectId;
  SyncObjectMutationType mutationType;
  Map<String, dynamic>? data;
  int ts;

  String getSignature() {
    final str = "$schemaName-$objectId";
    return md5.convert(utf8.encode(str)).toString();
  }

  Map<String, dynamic> toDbValues() {
    final values = {
      "schema_name": schemaName,
      "object_id": objectId,
      "mutation_type": mutationType.index,
      "data": jsonEncode(data),
      "ts": ts,
    };

    return values;
  }

  Map<String, dynamic> toJson() {
    return {
      "schema_name": schemaName,
      "object_id": objectId,
      "mutation_type": mutationType.index,
      "data": data,
      "ts": ts,
    };
  }
}
