import 'dart:async';

import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';

import '_local_sync_engine.dart';

class SyncEngine {
  static const SYNC_SCHEMAS = [Coil.SCHEMA_NAME, Location.SCHEMA_NAME];

  late final LocalSyncEngine _localEngine;
  late final Api _api;

  SyncEngine(DbConn db) {
    _localEngine = LocalSyncEngine(db);
    _api = Api();
  }

  Future<bool> sync() async {
    final versionsResp = await _api.schemaVersions();
    if (!versionsResp.isSuccess) {
      return false;
    }
    final unsynced = _localEngine.getUnsynced(versionsResp.body!);
    final unsyncedResp = await _api.changes(unsynced);
    if (!unsyncedResp.isSuccess) {
      return false;
    }

    for (var changeset in unsyncedResp.body!) {
      _localEngine.saveRemoteChangeset(changeset);
    }

    return true;
  }

}



