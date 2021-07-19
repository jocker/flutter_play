import 'dart:async';
import 'dart:collection';

import 'package:vgbnd/data/db.dart';

import '../schema.dart';
import '../sync.dart';
import '_local_repository.dart';

mixin SchemaInfoRepository{
  DbConn getDb();
  Map<String, LocalSchemaInfo>? _localSchemaInfos;
  final _changedStreamController = StreamController<SchemaChangedEvent>.broadcast();

  Map<String, LocalSchemaInfo> get localSchemaInfos {
    if (_localSchemaInfos == null) {
      final dest = new HashMap<String, LocalSchemaInfo>();

      final cursor = getDb().select(
          "select schema_name,local_revision_num,id_counter from ${LocalSchemaInfo.TABLE_NAME} where schema_name in ${DbConn.sqlIn(SyncEngine.SYNC_SCHEMAS)}");

      cursor.map((c) {
        String schemaName = c.getValueAt(columnName: "schema_name");
        int revNum = c.getValueAt(columnName: "local_revision_num");
        int idCounter = c.getValueAt(columnName: "id_counter");

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
    getDb().runInTransaction((tx) {
      for (var schemaVersion in data) {
        tx.upsert(LocalSchemaInfo.TABLE_NAME, {"schema_name": schemaVersion.schemaName},
            {"local_revision_num": schemaVersion.revNum});
      }
      return true;
    });
  }



  setSchemaRevNumber(String schemaName, int revNumber, {DbConn? db}) {
    final info = this.localSchemaInfos[schemaName];
    if (info != null && (info.revNum != revNumber)) {
      _upsertSchemaInfo(schemaName, {"local_revision_num": revNumber}, db: db);
      info.revNum = revNumber;
      info.invalidateVersion();
    }

  }

  setSchemaIdCounter(String schemaName, int idCounter, {DbConn? db}) {
    final info = this.localSchemaInfos[schemaName];
    if (info != null && (info.idCounter != idCounter)) {
      _upsertSchemaInfo(schemaName, {"id_counter": idCounter}, db: db);
      info.idCounter = idCounter;
    }
  }

  _upsertSchemaInfo(String schemaName, Map<String, dynamic> values, {DbConn? db}) {
    (db ?? getDb()).upsert(LocalSchemaInfo.TABLE_NAME, {"schema_name": schemaName}, values);
  }

  Stream<SchemaChangedEvent> onSchemaChanged() {
    return _changedStreamController.stream;
  }

  resetSchemaInfos(){
    _localSchemaInfos = null;
  }

  disposeSchemaInfos(){
    _changedStreamController.close();
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
  int revNum; // the revision number of the collection which we received the last time we pulled it from the server
  int idCounter; // used for generating new ids for records which are inserted locally only
  int versionNumber = _nextVersionNumber(); // this will get updated whenever anything changes(locally or remotely)
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