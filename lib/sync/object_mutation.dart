import 'dart:convert';

import 'package:vgbnd/sync/constants.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/value_holder.dart';

import '../ext.dart';
import 'mutation/sync_object_snapshot.dart';

class ObjectMutationData {
  static const TABLE_NAME = "_schema_changelog";

  static const STATUS_NONE = 0, STATUS_PENDING = 1, STATUS_SUCCESS = 2, STATUS_FAILURE = 3;

  static ObjectMutationData fromModel(SyncObject instance, SyncObjectMutationType op) {
    return ObjectMutationData(
        schemaName: instance.getSchema().schemaName,
        objectId: instance.id ?? 0,
        operation: op,
        status: STATUS_NONE,
        id: uuidGenV4());
  }

  static ObjectMutationData? fromJson(Map<String, dynamic> json) {

    return ObjectMutationData(
        id: json["id"],
        schemaName: json["schema_name"],
        objectId: json["object_id"],
        operation: SyncObjectMutationType.values[json["operation"]],
        status: json["status"],
        data: json["data"],
        errorMessages: json["error_messages"])
      ..snapshot = SyncObjectSnapshot.fromJson(json["snapshot"]);
  }

  static ObjectMutationData? fromDbValues(Map<String, dynamic> dbValues) {
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
    final rawOp = c.getValue<int>("operation");
    final rawStatus = c.getValue<int>("status");

    if (rawObjectId == null || rawOp == null || rawStatus == null) {
      return null;
    }

    SyncObjectMutationType? op;
    if (rawOp >= 0 && rawOp < SyncObjectMutationType.values.length) {
      op = SyncObjectMutationType.values[rawOp];
    }

    if (op == null) {
      return null;
    }

    final rec = ObjectMutationData(
        id: rawUUid, schemaName: rawSchemaName, objectId: rawObjectId, operation: op, status: rawStatus);

    final rawData = c.getValue<String>("data");
    if (rawData != null) {
      try {
        rec.data = jsonDecode(rawData);
      } catch (e) {}
    }

    final rawErrs = c.getValue<String>("error_messages");
    if (rawErrs != null) {
      try {
        rec.errorMessages = jsonDecode(rawErrs);
      } catch (e) {}
    }

    rec.createdAt = c.getValue<DateTime>("created_at");

    return rec;
  }

  ObjectMutationData(
      {required this.id,
      required this.schemaName,
      required this.objectId,
      required this.operation,
      required this.status,
      this.data,
      this.errorMessages,
      this.createdAt});

  String id;
  SchemaName schemaName;
  int objectId;
  SyncObjectMutationType operation;
  int status;
  DateTime? createdAt;
  Map<String, dynamic>? data;

  Map<String, dynamic>? errorMessages;

  SyncObjectSnapshot? snapshot; // what was the data before this changelog was created

  Map<String, dynamic> toDbValues() {
    final values = {
      "id": id,
      "schema_name": schemaName,
      "object_id": objectId,
      "operation": operation.index,
      "status": status,
      "data": jsonEncode(data),
      "error_messages": jsonEncode(errorMessages),
    };

    if (createdAt != null) {
      values["created_at"] = createdAt!.toIso8601String();
    }

    return values;
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "schema_name": schemaName,
      "object_id": objectId,
      "operation": operation.index,
      "status": status,
      "data": data,
      "error_messages": errorMessages,
      "snapshot": this.snapshot?.toJson(),
    };
  }
}
