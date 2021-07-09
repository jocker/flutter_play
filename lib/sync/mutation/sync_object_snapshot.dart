import 'dart:convert';
import 'dart:core';

import 'package:vgbnd/sync/value_holder.dart';

class SyncObjectSnapshot {
  static const TABLE_NAME = "_sync_object_snapshots";

  final String schemaName;
  final int objectId;
  final int revNum;
  final Map<String, dynamic> data;

  static SyncObjectSnapshot? fromJson(Map<String, dynamic> json) {
    new SyncObjectSnapshot(
        schemaName: json["schema_name"], data: json["data"], objectId: json["object_id"], revNum: json["rev_num"]);
  }

  static SyncObjectSnapshot? fromDbValues(Map<String, dynamic> dbValues) {
    final vh = PrimitiveValueHolder.fromMap(dbValues);

    final schemaName = vh.getValue<String>("schema_name");
    final rawData = vh.getValue<String>("data");
    final objectId = vh.getValue<int>("object_id");
    final revNum = vh.getValue<int>("rev_num");

    Map<String, dynamic>? data;

    if (rawData != null) {
      try {
        data = jsonDecode(rawData);
      } catch (e) {}
    }

    if (schemaName == null || data == null || objectId == null || revNum == null) {
      return null;
    }

    return SyncObjectSnapshot(schemaName: schemaName, objectId: objectId, revNum: revNum, data: data);
  }

  SyncObjectSnapshot({required this.schemaName, required this.objectId, required this.revNum, required this.data});

  Map<String, dynamic> toSqlValues() {
    final rawData = jsonEncode(this.data);
    return {
      "schema_name": this.schemaName,
      "object_id": this.objectId,
      "rev_num": this.revNum,
      "data": rawData,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      "schema_name": this.schemaName,
      "object_id": this.objectId,
      "rev_num": this.revNum,
      "data": this.data,
    };
  }
}
