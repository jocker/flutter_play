import 'dart:async';
import 'dart:collection';

import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync.dart';

class LocalSyncEngine {
  final DbConn _dbConn;

  LocalSyncEngine(this._dbConn);

  List<SchemaVersion> getUnsynced(List<SchemaVersion> remoteVersions) {
    List<SchemaVersion> needSync = [];

    for (var local in this.localSchemaInfos.values) {
      SchemaVersion? remote;
      try {
        remote = remoteVersions.firstWhere((element) => element.schemaName == local.schemaName, orElse: null);
      } catch (e) {}

      if (remote != null) {
        if (remote.revNum > local.revNum) {
          remote = null;
        }
      }

      if (remote == null) {
        needSync.add(SchemaVersion(local.schemaName, local.revNum));
      }
    }
    return needSync;
  }

  int nextLocalId(String schemaName) {
    final schemaInfo = this.localSchemaInfos[schemaName];
    if (schemaInfo == null) {
      return 0;
    }

    final nextId = schemaInfo.idCounter - 1;
    _setSchemaIdCounter(schemaName, nextId);
    return nextId;
  }

  Map<String, LocalSchemaInfo>? _localSchemaInfos;

  Map<String, LocalSchemaInfo> get localSchemaInfos {
    if (_localSchemaInfos == null) {
      final dest = new HashMap<String, LocalSchemaInfo>();

      for (var schemaName in SyncEngine.SYNC_SCHEMAS) {
        dest[schemaName] = LocalSchemaInfo.empty(schemaName);
      }

      final cursor = _dbConn.select(
          "select schema_name,local_revision_num,id_counter from ${LocalSchemaInfo.TABLE_NAME} where schema_name in ${DbConn.sqlIn(SyncEngine.SYNC_SCHEMAS)}");

      cursor.map((c) {
        String schemaName = c.getValue(columnName: "schema_name");
        int revNum = c.getValue(columnName: "local_revision_num");
        int idCounter = c.getValue(columnName: "id_counter");

        return LocalSchemaInfo(schemaName, revNum, idCounter);
      }).forEach((sch) {
        dest[sch.schemaName] = sch;
      });
      _localSchemaInfos = dest;
    }

    return _localSchemaInfos!;
  }

  saveVersions(Iterable<SchemaVersion> data) async {
    _dbConn.runInTransaction((tx) {
      for (var schemaVersion in data) {
        tx.upsert(LocalSchemaInfo.TABLE_NAME, {"schema_name": schemaVersion.schemaName},
            {"local_revision_num": schemaVersion.revNum});
      }
      return true;
    });
  }

  saveRemoteChangeset(RemoteSchemaChangeset changeset, {bool? useTempTable}) {
    final schema = SyncDbSchema.byName(changeset.collectionName);
    if (schema == null) {
      return;
    }

    _dbConn.runInTransaction((tx) {
      String destTableName = schema.tableName;
      if (useTempTable == true) {
        final tmpTableName = "_tmp_${schema.schemaName}_${DateTime.now().millisecondsSinceEpoch}";
        tx.execute("create temporary table $tmpTableName as select * from ${schema.schemaName} where false");
        destTableName = tmpTableName;
      }

      List<String> localColumnNames = schema.remoteReadableColumns.map((e) => e.name).toList();

      var deletedColIndex = -1;
      var idColIndex = -1;
      var remoteColIndex = -1;
      var remoteRevisionDateColIndex = -1;

      List<String> affectedColumnNames = [];
      List<int> remoteValueIndices = [];
      for (var key in changeset.remoteColumnNames) {
        remoteColIndex += 1;
        if (deletedColIndex < 0 && key == "deleted") {
          deletedColIndex = remoteColIndex;
          continue;
        }

        if (remoteRevisionDateColIndex < 0 && key == "updated_at") {
          remoteRevisionDateColIndex = remoteColIndex;
          continue;
        }

        if (idColIndex < 0 && key == "id") {
          idColIndex = remoteColIndex;
        }

        final colIdx = localColumnNames.indexOf(key);
        if (colIdx < 0) {
          continue;
        }
        affectedColumnNames.add(key);
        remoteValueIndices.add(colIdx);
      }

      final stm = tx.prepare(
          "insert or ignore into $destTableName( ${affectedColumnNames.join(",")} ) values ( ${affectedColumnNames.map((e) => "?").join(",")} )");

      final args = List<Object?>.filled(affectedColumnNames.length, null);
      final deleteItemIds = Set<String>();
      String? rawRevision;
      bool hasData = false;
      for (dynamic raw in changeset.data) {
        final row = raw.cast<Object?>();

        if (idColIndex >= 0 && row[deletedColIndex] == true) {
          final id = row[idColIndex];
          deleteItemIds.add(id.toString());
        }

        var idx = 0;
        for (var i in remoteValueIndices) {
          args[idx] = row[i];
          idx += 1;
        }

        if (remoteRevisionDateColIndex >= 0) {
          final v = row[remoteRevisionDateColIndex];
          if (v is String) {
            rawRevision = v;
          }
        }

        stm.execute(args);
        hasData = true;
      }

      if (hasData) {
        if (useTempTable == true) {
          final srcTableName = destTableName;
          final columnNames = affectedColumnNames.join(",");
          destTableName = schema.tableName;
          tx.execute("insert or replace into $destTableName( $columnNames ) select $columnNames from $srcTableName ");
          tx.execute("drop table $srcTableName ");
        }
      }

      if (deleteItemIds.isNotEmpty) {
        tx.execute("delete from ${schema.tableName} where id in (${deleteItemIds.join(", ")})");
      }

      if (rawRevision != null) {
        final revNum = SyncDbSchema.parseRevNum(rawRevision);
        if (revNum > 0) {
          _setSchemaRevNumber(schema.schemaName, revNum, db: tx);
        }
      }

      return true;
    });
  }

  _setSchemaRevNumber(String schemaName, int revNumber, {DbConn? db}) {
    final info = this.localSchemaInfos[schemaName];
    if (info != null) {
      _upsertSchemaInfo(schemaName, {"local_revision_num": revNumber}, db: db);
      info.revNum = revNumber;
    }
  }

  _setSchemaIdCounter(String schemaName, int idCounter, {DbConn? db}) {
    final info = this.localSchemaInfos[schemaName];
    if (info != null) {
      _upsertSchemaInfo(schemaName, {"id_counter": idCounter}, db: db);
      info.idCounter = idCounter;
    }
  }

  _upsertSchemaInfo(String schemaName, Map<String, dynamic> values, {DbConn? db}) {
    (db ?? _dbConn).upsert(LocalSchemaInfo.TABLE_NAME, {"schema_name": schemaName}, values);
  }
}

class LocalSchemaInfo {
  static const TABLE_NAME = '_schema_info';

  static LocalSchemaInfo empty(String schemaName) {
    return LocalSchemaInfo(schemaName, 0, 0);
  }

  String schemaName;
  int revNum;
  int idCounter;

  final _versionChangedStreamController = StreamController<int>();

  LocalSchemaInfo(this.schemaName, this.revNum, this.idCounter);
}
