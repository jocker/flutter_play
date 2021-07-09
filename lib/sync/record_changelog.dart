import 'dart:convert';

import 'package:vgbnd/data/cursor.dart';
import 'package:vgbnd/sync/persistence/sync_object_snapshor.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/constants.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/value_holder.dart';

import '../ext.dart';

class RecordChangelog {
  static const STATUS_NONE = 0, STATUS_PENDING = 1, STATUS_SUCCESS = 2, STATUS_FAILURE = 3;

  static RecordChangelog fromModel(SyncObject instance, SyncObjectOp op) {
    return RecordChangelog(
        schemaName: instance.getSchema().schemaName,
        recordId: instance.id ?? 0,
        operation: op,
        status: STATUS_NONE,
        id: uuidGenV4());
  }

  static RecordChangelog? fromDbValues(Map<String, dynamic> dbValues) {
    final c = PrimitiveValueHolder.fromMap(dbValues);
    final rawUUid = c.getValue<String>("uuid");
    if (rawUUid == null) {
      return null;
    }
    final rawSchemaName = c.getValue<String>("schema_name");
    if (rawSchemaName == null) {
      return null;
    }

    final rawRecordId = c.getValue<int>("record_id");
    final rawOp = c.getValue<int>("operation");
    final rawStatus = c.getValue<int>("status");

    if (rawRecordId == null || rawOp == null || rawStatus == null) {
      return null;
    }

    SyncObjectOp? op;
    if (rawOp >= 0 && rawOp < SyncObjectOp.values.length) {
      op = SyncObjectOp.values[rawOp];
    }

    if (op == null) {
      return null;
    }

    final rec = RecordChangelog(
        id: rawUUid, schemaName: rawSchemaName, recordId: rawRecordId, operation: op, status: rawStatus);

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

  RecordChangelog(
      {required this.id,
      required this.schemaName,
      required this.recordId,
      required this.operation,
      required this.status,
      this.data,
      this.errorMessages,
      this.createdAt});

  String id;
  SchemaName schemaName;
  int recordId;
  SyncObjectOp operation;
  int status;
  DateTime? createdAt;
  Map<String, dynamic>? data;

  Map<String, dynamic>? errorMessages;

  SyncObjectSnapshot? snapshot;

  Map<String, dynamic> toDbValues() {
    final values = {
      "id": id,
      "schema_name": schemaName,
      "record_id": recordId,
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
}
