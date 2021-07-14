import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/value_holder.dart';

import 'mutation/sync_object_snapshot.dart';

class ObjectMutationData {
  static const TABLE_NAME = "_sync_pending_remote_mutations";

  static const STATUS_NONE = 0, STATUS_PENDING = 1, STATUS_SUCCESS = 2, STATUS_FAILURE = 3;

  static ObjectMutationData fromModel(SyncObject instance, SyncObjectMutationType op) {
    return ObjectMutationData(
        schemaName: instance.getSchema().schemaName,
        objectId: instance.id ?? 0,
        mutationType: op,
        status: STATUS_NONE,
        revNum: DateTime.now().millisecondsSinceEpoch);
  }

  static ObjectMutationData? fromJson(Map<String, dynamic> json) {
    return ObjectMutationData(
        schemaName: json["schema_name"],
        objectId: json["object_id"],
        mutationType: SyncObjectMutationType.values[json["mutation_type"]],
        status: json["status"],
        data: json["data"],
        revNum: json["rev_num"],
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
    final rawOp = c.getValue<int>("mutation_type");
    final rawStatus = c.getValue<int>("status");
    final rawRevNum = c.getValue<int>("rev_num");

    if (rawObjectId == null || rawOp == null || rawStatus == null || rawRevNum == null) {
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
        schemaName: rawSchemaName, objectId: rawObjectId, mutationType: op, status: rawStatus, revNum: rawRevNum);

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

    return rec;
  }

  ObjectMutationData(
      {required this.schemaName,
      required this.objectId,
      required this.mutationType,
      required this.status,
      required this.revNum,
      this.data,
      this.errorMessages});

  SchemaName schemaName;
  int objectId;
  SyncObjectMutationType mutationType;
  int status;
  int revNum;
  Map<String, dynamic>? data;

  Map<String, dynamic>? errorMessages;

  SyncObjectSnapshot? snapshot; // what was the data before this changelog was created

  String getSignature() {
    final str = "$schemaName-$objectId-$revNum";
    return md5.convert(utf8.encode(str)).toString();
  }

  Map<String, dynamic> toDbValues() {
    final values = {
      "schema_name": schemaName,
      "object_id": objectId,
      "mutation_type": mutationType.index,
      "data": jsonEncode(data),
      "error_messages": jsonEncode(errorMessages),
      "status": status,
      "rev_num": this.revNum,
    };

    return values;
  }

  Map<String, dynamic> toJson() {
    return {
      "schema_name": schemaName,
      "object_id": objectId,
      "mutation_type": mutationType.index,
      "data": data,
      "error_messages": errorMessages,
      "status": status,
      "rev_num": this.revNum,
      "snapshot": this.snapshot?.toJson(),
    };
  }
}
