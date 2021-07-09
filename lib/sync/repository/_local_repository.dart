import 'dart:math';

import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/ext.dart';
import 'package:vgbnd/sync/repository/schema_info_repository.dart';
import 'package:vgbnd/sync/repository/sync_object_repository.dart';
import 'package:vgbnd/sync/repository/sync_object_snapshot_repository.dart';
import 'package:vgbnd/sync/schema.dart';

import '../../ext.dart';

class LocalRepository with SyncObjectRepository, SyncObjectSnapshotRepository, SchemaInfoRepository {
  final DbConn _dbConn;
  bool _isDisposed = false;

  LocalRepository(this._dbConn);

  bool get isEmpty {
    for (var local in this.localSchemaInfos.values) {
      if (local.revNum > 0) {
        return false;
      }
    }
    return true;
  }

  DbConn get dbConn {
    return _dbConn;
  }

  List<SchemaVersion> getUnsynced(List<SchemaVersion> remoteVersions) {
    List<SchemaVersion> needSync = [];

    for (var local in this.localSchemaInfos.values) {
      var remote = remoteVersions.firstWhereOrNull((element) => element.schemaName == local.schemaName);

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

  int getSchemaVersion(String schemaName) {
    final schemaInfo = this.localSchemaInfos[schemaName];
    if (schemaInfo == null) {
      return 0;
    }

    return schemaInfo.revNum;
  }

  reset() {
    _dbConn.reconnect();
    resetSchemaInfos();
  }

  int saveRemoteChangeset(RemoteSchemaChangelog changeset, {bool? useTempTable}) {
    int changesetRevNum = 0;

    final schema = SyncSchema.byName(changeset.schemaName);
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

      final args = List<Object?>.filled(changeset.schemaAttributeNames.length, null);
      final deleteItemIds = Set<String>();
      bool hasData = false;

      final schemaAttributeNames = changeset.schemaAttributeNames;

      final stm = tx.prepare(
          "insert or ignore into $destTableName( ${schemaAttributeNames.join(",")} ) values ( ${schemaAttributeNames.map((e) => "?").join(",")} )");

      for (var entry in changeset.entries()) {
        try{
          if (entry.isDeleted == true) {
            if (entry.id != null) {
              deleteItemIds.add(entry.id!);
            }
            continue;
          }
        }catch(e){
          rethrow;
        }


        changesetRevNum = max(entry.revisionNum ?? changesetRevNum, changesetRevNum );

        entry.putSchemaValues(args);
        stm.execute(args);
        hasData = true;
      }

      if (hasData) {
        if (useTempTable == true) {
          final srcTableName = destTableName;
          final columnNames = schemaAttributeNames.join(",");
          destTableName = schema.tableName;
          tx.execute("insert or replace into $destTableName( $columnNames ) select $columnNames from $srcTableName ");
          tx.execute("drop table $srcTableName ");
        }
      }

      if (deleteItemIds.isNotEmpty) {
        tx.execute("delete from ${schema.tableName} where id in (${deleteItemIds.join(", ")})");
      }

      schema.onChangesetApplied(changeset, tx);
      return true;
    });
    if (changesetRevNum > 0) {
      this.setSchemaRevNumber(schema.schemaName, changesetRevNum);
    }
    return changesetRevNum;
  }

  dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _dbConn.dispose();
      disposeSchemaInfos();
    }
  }

  @override
  DbConn getDb() {
    return _dbConn;
  }

  @override
  int getNextInsertId(String schemaName) {
    final schemaInfo = this.localSchemaInfos[schemaName];
    if (schemaInfo == null) {
      return 0;
    }

    final nextId = schemaInfo.idCounter - 1;
    setSchemaIdCounter(schemaName, nextId);
    return nextId;
  }
}

class SchemaChangedEvent {
  final String schemaName;
  final int versionNum;

  SchemaChangedEvent(this.schemaName, this.versionNum);
}
