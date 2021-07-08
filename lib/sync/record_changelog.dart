import 'dart:convert';

import 'package:vgbnd/data/cursor.dart';
import 'package:vgbnd/models/base_model.dart';
import 'package:vgbnd/sync/constants.dart';
import 'package:vgbnd/sync/schema.dart';

import '../ext.dart';

class RecordChangelog {
  static const STATUS_NONE = 0, STATUS_PENDING = 1, STATUS_SUCCESS = 2, STATUS_FAILURE = 3;

  static RecordChangelog fromModel(BaseModel instance, SyncRecordOp op) {
    return RecordChangelog(
        schemaName: instance.getSchema().schemaName,
        recordId: instance.id ?? 0,
        operation: op,
        status: STATUS_NONE,
        id: uuidGenV4());
  }

  static RecordChangelog? fromCursor(Cursor c) {
    final rawUUid = c.getValue<String>(columnName: "uuid");
    if (rawUUid == null) {
      return null;
    }
    final rawSchemaName = c.getValue<String>(columnName: "schema_name");
    if (rawSchemaName == null) {
      return null;
    }

    final rawRecordId = c.getValue<int>(columnName: "record_id");
    final rawOp = c.getValue<int>(columnName: "operation");
    final rawStatus = c.getValue<int>(columnName: "status");

    if (rawRecordId == null || rawOp == null || rawStatus == null) {
      return null;
    }

    SyncRecordOp? op;
    if (rawOp >= 0 && rawOp < SyncRecordOp.values.length) {
      op = SyncRecordOp.values[rawOp];
    }

    if (op == null) {
      return null;
    }

    final rec = RecordChangelog(
        id: rawUUid, schemaName: rawSchemaName, recordId: rawRecordId, operation: op, status: rawStatus);

    final rawData = c.getValue<String>(columnName: "data");
    if (rawData != null) {
      try {
        rec.data = jsonDecode(rawData);
      } catch (e) {}
    }

    final rawErrs = c.getValue<String>(columnName: "error_messages");
    if (rawErrs != null) {
      try {
        rec.errorMessages = jsonDecode(rawErrs);
      } catch (e) {}
    }

    rec.createdAt = c.getValue<DateTime>(columnName: "created_at");

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
  SyncRecordOp operation;
  int status;
  DateTime? createdAt;
  Map<String, dynamic>? data;

  Map<String, dynamic>? errorMessages;

  Map<String, dynamic> toSqlValues() {
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
