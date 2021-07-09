import 'dart:convert';
import 'dart:core';

import 'package:vgbnd/sync/value_holder.dart';

class SyncObjectSnapshot {
  final String schemaName;
  final int recordId;
  final int revNum;
  final Map<String, dynamic> data;

  static SyncObjectSnapshot? fromDbValues(Map<String, dynamic> dbValues) {
    final vh = PrimitiveValueHolder.fromMap(dbValues);

    final schemaName = vh.getValue<String>("schema_name");
    final rawData = vh.getValue<String>("data");
    final recId = vh.getValue<int>("record_id");
    final revNum = vh.getValue<int>("rev_num");

    Map<String, dynamic>? data;

    if (rawData != null) {
      try {
        data = jsonDecode(rawData);
      } catch (e) {}
    }

    if (schemaName == null || data == null || recId == null || revNum == null) {
      return null;
    }

    return SyncObjectSnapshot(schemaName: schemaName, recordId: recId, revNum: revNum, data: data);
  }

  SyncObjectSnapshot({required this.schemaName, required this.recordId, required this.revNum, required this.data});

  Map<String, dynamic> toSqlValues() {
    final rawData = jsonEncode(this.data);
    return {
      "schema_name": this.schemaName,
      "record_id": this.recordId,
      "rev_num": this.revNum,
      "data": rawData,
    };
  }
}
