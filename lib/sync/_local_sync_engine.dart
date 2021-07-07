import 'dart:async';
import 'dart:collection';

import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync.dart';

class LocalSyncEngine {
  final DbConn _dbConn;
  bool _isDisposed = false;
  final _changedStreamController = StreamController<SchemaChangedEvent>.broadcast();

  LocalSyncEngine(this._dbConn);

  bool get isEmpty{
    for (var local in this.localSchemaInfos.values) {
      if(local.revNum > 0){
        return false;
      }
    }
    return true;
  }

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
    _setLocalIdCounter(schemaName, nextId);
    return nextId;
  }

  Map<String, LocalSchemaInfo>? _localSchemaInfos;

  Map<String, LocalSchemaInfo> get localSchemaInfos {
    if (_localSchemaInfos == null) {
      final dest = new HashMap<String, LocalSchemaInfo>();

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

      for (var schemaName in SyncEngine.SYNC_SCHEMAS) {
        if (dest.containsKey(schemaName)) {
          continue;
        }
        dest[schemaName] = LocalSchemaInfo.empty(schemaName);
      }

      for (var schemaInfo in dest.values) {
        schemaInfo.onChanged((ev) {
          _changedStreamController.sink.add(ev);
        });
      }

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

  reset() {
    _dbConn.reconnect();
    _localSchemaInfos = null;
  }

  int saveRemoteChangeset(RemoteSchemaChangeset changeset, {bool? useTempTable}) {
    int changesetRevNum = 0;

    final schema = SyncDbSchema.byName(changeset.collectionName);
    if (schema == null) {
      return changesetRevNum;
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
        remoteValueIndices.add(remoteColIndex);
      }

      final stm = tx.prepare(
          "insert or ignore into $destTableName( ${affectedColumnNames.join(",")} ) values ( ${affectedColumnNames.map((e) => "?").join(",")} )");

      final args = List<Object?>.filled(affectedColumnNames.length, null);
      final deleteItemIds = Set<String>();
      String? rawRevision;
      bool hasData = false;
      for (dynamic raw in changeset.data) {
        final row = raw.cast<Object?>();

        if (deletedColIndex >= 0 && idColIndex >= 0 && row[deletedColIndex] == true) {
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
        if (revNum != null) {
          _setRevNumber(schema.schemaName, revNum, db: tx);
          changesetRevNum = revNum;
        }
      }

      return true;
    });
    if (changesetRevNum > 0) {
      localSchemaInfos[changeset.collectionName]!.invalidateVersion();
    }
    return changesetRevNum;
  }

  _setRevNumber(String schemaName, int revNumber, {DbConn? db}) {
    final info = this.localSchemaInfos[schemaName];
    if (info != null && (info.revNum != revNumber)) {
      _upsertSchemaInfo(schemaName, {"local_revision_num": revNumber}, db: db);
      info.revNum = revNumber;
    }
  }

  _setLocalIdCounter(String schemaName, int idCounter, {DbConn? db}) {
    final info = this.localSchemaInfos[schemaName];
    if (info != null && (info.idCounter != idCounter)) {
      _upsertSchemaInfo(schemaName, {"id_counter": idCounter}, db: db);
      info.idCounter = idCounter;
    }
  }

  _upsertSchemaInfo(String schemaName, Map<String, dynamic> values, {DbConn? db}) {
    (db ?? _dbConn).upsert(LocalSchemaInfo.TABLE_NAME, {"schema_name": schemaName}, values);
  }

  Stream<SchemaChangedEvent> onSchemaChanged() {
    return _changedStreamController.stream;
  }

  dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _dbConn.dispose();
      _changedStreamController.close();
    }
  }
}

class LocalSchemaInfo {
  static int _schemaVersionCounter = 1;

  static int _nextVersionNumber() {
    _schemaVersionCounter += 1;
    return _schemaVersionCounter;
  }

  static const TABLE_NAME = '_schema_info';

  static LocalSchemaInfo empty(String schemaName) {
    return LocalSchemaInfo(schemaName, 0, 0);
  }

  String schemaName;
  int revNum;
  int idCounter;
  int versionNumber = _nextVersionNumber();
  Function(SchemaChangedEvent ev)? _onChangedListener;

  LocalSchemaInfo(this.schemaName, this.revNum, this.idCounter);

  onChanged(Function(SchemaChangedEvent ev) fn) {
    _onChangedListener = fn;
  }

  invalidateVersion() {
    versionNumber = _nextVersionNumber();
    final listener = _onChangedListener;
    if (listener != null) {
      listener(SchemaChangedEvent(this.schemaName, versionNumber));
    }
  }
}

class SchemaChangedEvent {
  final String schemaName;
  final int versionNum;

  SchemaChangedEvent(this.schemaName, this.versionNum);
}
