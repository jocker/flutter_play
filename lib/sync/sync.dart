import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/bkg/task_runner.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/models/machine_column_sales.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/models/productlocation.dart';
import 'package:vgbnd/sync/schema.dart';

import '_local_sync_engine.dart';

const _MESSAGE_TYPE_PULL_CHANGES = "pull_changes",
    _MESSAGE_TYPE_INVALIDATE_CACHE = "invalidate_cache",
    _MESSAGE_TYPE_WATCH_SCHEMA_CHANGED = "watch_schema_changed";

class SyncEngineIsolate {
  late final LocalSyncEngine _localEngine;
  late final Api _api;
  final UserAccount _account;
  final DbConn _db;

  SyncEngineIsolate(this._db, this._account) {
    _localEngine = LocalSyncEngine(_db);
    _api = Api();
  }

  Future<bool> pullChanges() async {
    List<SchemaVersion> unsynced = [];
    var includeDeleted = false;
    if (!_localEngine.isEmpty) {
      final versionsResp = await _api.schemaVersions(_account);
      if (!versionsResp.isSuccess) {
        return false;
      }
      unsynced = _localEngine.getUnsynced(versionsResp.body!);
      includeDeleted = true;
    } else {
      unsynced.addAll(SyncEngine.SYNC_SCHEMAS.map((e) => SchemaVersion(e, 0)));
    }

    final unsyncedResp = await _api.changes(_account, unsynced, includeDeleted: includeDeleted);
    if (!unsyncedResp.isSuccess) {
      return false;
    }

    for (var changeset in unsyncedResp.body!) {
      _localEngine.saveRemoteChangeset(changeset);
    }

    return true;
  }

  Future<bool> invalidateLocalCache() async {
    _localEngine.reset();
    return await pullChanges();
  }

  Future<WatchSchemasReply> watchSchemas(WatchSchemasMessage ask) async {
    var prevNum = _getSchemaSignature(ask.schemas);
    final initial = prevNum;
    final subscription = _localEngine.onSchemaChanged().listen((event) {
      if (ask.schemas.contains(event.schemaName)) {
        var newNum = _getSchemaSignature(ask.schemas);
        if (prevNum != newNum) {
          ask.notifyPort.send(newNum);
          prevNum = newNum;
        }
      }
    });

    final cancel = ReceivePort();
    cancel.listen((message) {
      cancel.close();
      subscription.cancel();
    });

    return WatchSchemasReply(initial, cancel.sendPort);
  }

  _getSchemaSignature(List<String> schemaNames) {
    int res = 0;
    for (var name in schemaNames) {
      final versionNum = _localEngine.localSchemaInfos[name]?.versionNumber ?? -1;
      if (versionNum < 0) {
        continue;
      }
      res = 31 * res + versionNum;
    }
    return res;
  }

  dynamic processMessage(TaskMessage message) async {
    switch (message.type) {
      case _MESSAGE_TYPE_PULL_CHANGES:
        return await pullChanges();
      case _MESSAGE_TYPE_INVALIDATE_CACHE:
        return await invalidateLocalCache();
      case _MESSAGE_TYPE_WATCH_SCHEMA_CHANGED:
        final ask = message.args as WatchSchemasMessage;
        return await watchSchemas(ask);
      default:
        throw Exception("SyncEngineBackEnd doesn't know how to handle ${message.type}");
    }
  }
}

// runs in the main isolate and schedules tasks to run in a background isloate
class SyncEngine extends TaskRunner {
  static final _instances = HashMap<int, SyncEngine>();

  static SyncEngine forAccount(UserAccount account) {
    if (!_instances.containsKey(account.id)) {
      _instances[account.id] = SyncEngine(account);
    }
    return _instances[account.id]!;
  }

  static const SYNC_SCHEMAS = [
    Coil.SCHEMA_NAME,
    Location.SCHEMA_NAME,
    Product.SCHEMA_NAME,
    ProductLocation.SCHEMA_NAME,
    MachineColumnSale.SCHEMA_NAME
  ];

  static _runTasks(SetupMessage setupMessage) async {
    final args = setupMessage.args as Map<String, dynamic>;
    final account = UserAccount.fromJson(args['account']);

    final db = await DbConn.open(args['db_path'], runMigrations: false);
    final backend = SyncEngineIsolate(db, account);

    TaskRunner.runnerFunc(setupMessage.onComplete, processMessage: backend.processMessage);
  }

  final UserAccount _userAccount;

  SyncEngine(this._userAccount) {
    scheduleMicrotask(() async {
      // plugins can run only in the main isolate
      final dbPath = await getLocalDatabasePath();
      await DbConn.runMigrations(dbPath);

      Map<String, dynamic> args = {"account": _userAccount.toJson(), "db_path": dbPath};
      setup(initIsolate: _runTasks, setupArgs: args);
    });
  }

  Future<bool> pullChanges() async {
    bool success = await this.exec(_MESSAGE_TYPE_PULL_CHANGES);
    return success;
  }

  Future<bool> invalidateLocalCache() async {
    final dbPath = await getLocalDatabasePath();
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
    await DbConn.runMigrations(dbPath);
    bool success = await this.exec(_MESSAGE_TYPE_INVALIDATE_CACHE);
    return success;
  }

  Future<Stream<int>> watchSchemas(List<String> schemaNames) async {
    final p = ReceivePort();
    WatchSchemasReply reply =
        await this.exec(_MESSAGE_TYPE_WATCH_SCHEMA_CHANGED, args: WatchSchemasMessage(p.sendPort, schemaNames));

    StreamController<int> controller = StreamController<int>(
      onCancel: () {
        reply.cancelPort.send(true);
        p.close();
      },
    );

    p.listen((message) {
      controller.sink.add(message as int);
    });

    return controller.stream;
  }

  Future<String> getLocalDatabasePath() async {
    final docsPath = (await getApplicationDocumentsDirectory()).path;
    final databasesPath = path.join(docsPath, "databases");
    await Directory(databasesPath).create(recursive: true);

    return path.join(databasesPath, "data_${_userAccount.id}.db");
  }
}

class WatchSchemasMessage {
  final SendPort notifyPort;
  final List<String> schemas;

  WatchSchemasMessage(this.notifyPort, this.schemas);
}

class WatchSchemasReply {
  final SendPort cancelPort;
  final int dataVersion;

  WatchSchemasReply(this.dataVersion, this.cancelPort);
}
