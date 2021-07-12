import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/bkg/task_runner.dart';
import 'package:vgbnd/data/cursor.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/data/matrix_cursor.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/models/machine_column_sales.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/models/productlocation.dart';
import 'package:vgbnd/sync/constants.dart';
import 'package:vgbnd/sync/object_mutation.dart';
import 'package:vgbnd/sync/repository/_remote_repository.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

import 'mutation/mutation.dart';
import 'net_connectivity_info.dart';
import 'repository/_local_repository.dart';

const _MESSAGE_TYPE_PULL_CHANGES = "pull_changes",
    _MESSAGE_TYPE_INVALIDATE_CACHE = "invalidate_cache",
    _MESSAGE_TYPE_WATCH_SCHEMA_CHANGED = "watch_schema_changed",
    _MESSAGE_TYPE_SET_CONN_INFO = "set_conn_info",
    _MESSAGE_TYPE_MUTATE_SYNC_OBJECT = "mutate_sync_object",
    _MESSAGE_TYPE_FETCH_CURSOR = "fetch_cursor";

class SyncEngineIsolate {
  late final LocalRepository _localRepository;
  late final RemoteRepository _remoteRepository;

  final UserAccount _account;
  final DbConn _db;
  final NetConnectivityInfo _connectivityInfo;

  SyncEngineIsolate(this._db, this._account, this._connectivityInfo) {
    _localRepository = LocalRepository(_db);
    _remoteRepository = RemoteRepository(this._account, this._connectivityInfo);
  }

  MutationResult _processChangelog(List<RemoteSchemaChangelog> changelogs) {
    final mutResult = MutationResult(SyncStorageType.Remote);

    for (var changelog in changelogs) {
      final schema = SyncSchema.byName(changelog.schemaName);
      if (schema == null) {
        continue;
      }

      int? maxRemoteID;

      final idColName = schema.idColumn?.name;
      if (idColName != null) {
        maxRemoteID = _localRepository.dbConn
            .selectValue<int?>("select coalesce(0, (select max($idColName}) from ${schema.tableName}))");
      }

      for (var entry in changelog.entries()) {
        final syncObject = entry.toSyncObject();
        if (syncObject == null) {
          continue;
        }

        if (entry.isDeleted == true) {
          mutResult.add(SyncObjectMutationType.Delete, syncObject);
        }

        if (maxRemoteID != null && maxRemoteID < syncObject.getId()) {
          mutResult.add(SyncObjectMutationType.Create, syncObject);
        } else {
          mutResult.add(SyncObjectMutationType.Update, syncObject);
        }
      }
    }

    mutResult.setSuccessful(true);
    return mutResult;
  }

  Future<bool> pullChanges() async {
    List<SchemaVersion> unsynced = [];
    var includeDeleted = false;
    if (!_localRepository.isEmpty) {
      final versionsResp = await _remoteRepository.schemaVersions();
      if (!versionsResp.isSuccess) {
        return false;
      }
      unsynced = _localRepository.getUnsynced(versionsResp.body!);
      includeDeleted = true;
    } else {
      unsynced.addAll(SyncEngine.SYNC_SCHEMAS.map((e) => SchemaVersion(e, 0)));
    }

    unsynced = unsynced.where((element) => SyncSchema.byName(element.schemaName)?.remoteReadable ?? false).toList();
    final unsyncedResp = await _remoteRepository.changes(unsynced, includeDeleted: includeDeleted);
    if (!unsyncedResp.isSuccess) {
      return false;
    }

    for (var changeset in unsyncedResp.body!) {
      _localRepository.saveRemoteChangeset(changeset);
    }

    return true;
  }

  Future<bool> invalidateLocalCache() async {
    _localRepository.reset();
    return await pullChanges();
  }

  Future<WatchSchemasReply> watchSchemas(WatchSchemasMessage ask) async {
    var prevNum = _getSchemaSignature(ask.schemas);
    final initial = prevNum;
    final subscription = _localRepository.onSchemaChanged().listen((event) {
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

  Future<MutationResult> handleMutationRequest(MutateSyncObjectMessage req) async {
    final syncObject = req.getObject();
    if (syncObject == null) {
      return MutationResult.failure();
    }
    final schema = syncObject.getSchema();

    if (!schema.localMutationHandler.canHandleMutationType(req.op)) {
      return MutationResult.failure();
    }

    final mutData = await schema.localMutationHandler.createMutation(_localRepository, syncObject, req.op);
    if (mutData == null) {
      return MutationResult.failure();
    }

    if (schema.remoteMutationHandler.canHandleMutationType(req.op)) {
      if (_connectivityInfo.networkingEnabled) {
        MutationResult? remoteResult;
        try {
          remoteResult =
              await schema.remoteMutationHandler.submitMutation(mutData, _localRepository, _remoteRepository);
        } on RemoteMutationException catch (e) {
          return e.asMutationResult();
        }
        final res =
            await schema.remoteMutationHandler.applyRemoteMutationResult(mutData, remoteResult, _localRepository);
        _handleMutationResult(res);
        return res;
      } else {
        // enqueue this mutation for submitting it later
        _localRepository.dbConn.insert(ObjectMutationData.TABLE_NAME, mutData.toDbValues());
      }
    }

    final res = await schema.localMutationHandler.applyLocalMutation(mutData, _localRepository);
    _handleMutationResult(res);
    return res;
  }

  _handleMutationResult(MutationResult mutationRes) {
    if (mutationRes.isSuccessful) {
      _localRepository.dbConn.runInTransaction((tx) {
        final replacements = mutationRes.replacements;
        if (replacements != null) {
          for (final repl in replacements) {
            final schema = repl.object.getSchema();
            final idCol = schema.idColumn;
            if (idCol == null) {
              continue;
            }

            tx.execute(
                "update ${schema.tableName} set ${idCol.name}=? where ${idCol.name} =? ", [repl.newId, repl.prevId]);

            tx.insert(
                "_sync_object_resolved_ids",
                {
                  "schema_name": schema.schemaName,
                  "local_id": repl.prevId,
                  "remote_id": repl.newId,
                },
                onConflict: OnConflictDo.Ignore);
          }
        }

        final created = mutationRes.created;
        if (created != null) {
          for (final rec in created) {
            _localRepository.insertValues(rec.getSchema(), rec.dumpValues().toMap(),
                db: tx, onConflict: OnConflictDo.Replace);
          }
        }

        final updated = mutationRes.updated;
        if (updated != null) {
          for (final rec in updated) {
            _localRepository.updateEntry(rec.getSchema(), rec.getId(), rec.dumpValues().toMap(), db: tx);
          }
        }

        final deleted = mutationRes.deleted;
        if (deleted != null) {
          for (final rec in deleted) {
            _localRepository.deleteEntry(rec.getSchema(), rec.getId(), db: tx);
          }
        }

        return true;
      });

      for (final schemaName in mutationRes.affectedSchemas()) {
        _localRepository.localSchemaInfos[schemaName]?.invalidateVersion();
      }
    }
  }

  _getSchemaSignature(List<String> schemaNames) {
    int res = 0;
    for (var name in schemaNames) {
      final versionNum = _localRepository.localSchemaInfos[name]?.versionNumber ?? -1;
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
      case _MESSAGE_TYPE_SET_CONN_INFO:
        _connectivityInfo.setValue(message.args as int);
        return;
      case _MESSAGE_TYPE_MUTATE_SYNC_OBJECT:
        final msg = message.args as MutateSyncObjectMessage;
        return await handleMutationRequest(msg);
      case _MESSAGE_TYPE_FETCH_CURSOR:
        final msg = message.args as FetchCursorMessage;

        final cursor = this._localRepository.dbConn.select(msg.sql, msg.args);
        return cursor.toJson();

      default:
        throw Exception("SyncEngineBackEnd doesn't know how to handle ${message.type}");
    }
  }
}

// runs in the main isolate and schedules tasks to run in a background isloate
class SyncEngine extends TaskRunner {
  static final _instances = HashMap<int, SyncEngine>();

  static SyncEngine current() {
    return SyncEngine.forAccount(UserAccount.current);
  }

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
    MachineColumnSale.SCHEMA_NAME,
    Pack.SCHEMA_NAME
  ];

  static _runTasks(SetupMessage setupMessage) async {
    final args = setupMessage.args as Map<String, dynamic>;
    final account = UserAccount.fromJson(args['account']);

    final db = await DbConn.open(args['db_path'], runMigrations: false);
    final backend = SyncEngineIsolate(db, account, NetConnectivityInfo(args['conn_info']));

    TaskRunner.runnerFunc(setupMessage.onComplete, processMessage: backend.processMessage);
  }

  final UserAccount _userAccount;
  final NetConnectivityInfo _connectivityInfo = NetConnectivityInfo(0);
  late final StreamSubscription<ConnectivityResult> _subConnectivity;

  SyncEngine(this._userAccount) {
    scheduleMicrotask(() async {
      // plugins can run only in the main isolate
      final dbPath = await getLocalDatabasePath();
      await DbConn.runMigrations(dbPath);

      await _setupConnectivityInfo();

      Map<String, dynamic> args = {
        "account": _userAccount.toJson(),
        "db_path": dbPath,
        "conn_info": _connectivityInfo.value
      };
      setup(initIsolate: _runTasks, setupArgs: args);
    });
  }

  _setupConnectivityInfo() async {
    final conn = Connectivity();

    _connectivityInfo.onChanged((value) {
      emit(_MESSAGE_TYPE_SET_CONN_INFO, args: value);
    });

    _connectivityInfo.setConnectivityResult(await conn.checkConnectivity());

    _subConnectivity = conn.onConnectivityChanged.listen((event) {
      _connectivityInfo.setConnectivityResult(event);
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

  Future<MutationResult> mutateObject(SyncObject obj, SyncObjectMutationType op) async {
    return await this.exec(_MESSAGE_TYPE_MUTATE_SYNC_OBJECT, args: MutateSyncObjectMessage.forObject(obj, op));
  }

  Future<Cursor> fetchCursor(String sql, {List<Object>? args}) async {
    final Map<String, dynamic> cursorJson =
        await this.exec(_MESSAGE_TYPE_FETCH_CURSOR, args: FetchCursorMessage(sql, args ?? List.empty()));
    return MatrixCursor.fromJson(cursorJson);
  }

  Future<String> getLocalDatabasePath() async {
    final docsPath = (await getApplicationDocumentsDirectory()).path;
    final databasesPath = path.join(docsPath, "databases");
    await Directory(databasesPath).create(recursive: true);

    return path.join(databasesPath, "data_${_userAccount.id}.db");
  }

  @override
  bool dispose() {
    if (super.dispose()) {
      _instances.remove(_userAccount.id);
      _subConnectivity.cancel();
      return true;
    }
    return false;
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

class MutateSyncObjectMessage {
  final Map<String, dynamic> syncObjectAttrs;
  final String schemaName;
  final SyncObjectMutationType op;

  MutateSyncObjectMessage(this.schemaName, this.op, this.syncObjectAttrs);

  static MutateSyncObjectMessage forObject(SyncObject object, SyncObjectMutationType op) {
    return MutateSyncObjectMessage(
      object.getSchema().schemaName,
      op,
      object.dumpValues().toMap(),
    );
  }

  SyncObject? getObject() {
    return SyncSchema.byName(this.schemaName)?.instantiate(this.syncObjectAttrs);
  }
}

class FetchCursorMessage {
  final String sql;
  final List<Object?> args;

  FetchCursorMessage(this.sql, this.args);
}

class FetchCursorReply {
  List<String> headers;
  List<List<Object?>> rows;

  FetchCursorReply(this.headers, this.rows);
}
