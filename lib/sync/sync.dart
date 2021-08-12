import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mutex/mutex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/bkg/task_runner.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/controllers/auth_controller.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/data/sql_result_set.dart';
import 'package:vgbnd/ext.dart';
import 'package:vgbnd/helpers/sql_select_query.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/models/machine_column_sales.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/pack_entry.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/models/productlocation.dart';
import 'package:vgbnd/models/restock.dart';
import 'package:vgbnd/models/restock_entry.dart';
import 'package:vgbnd/sync/repository/remote_repository.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/sync_pending_remote_mutation.dart';

import 'mutation/mutation.dart';
import 'net_connectivity_info.dart';
import 'repository/local_repository.dart';

const _MESSAGE_TYPE_PULL_CHANGES = "pull_changes",
    _MESSAGE_TYPE_INVALIDATE_CACHE = "invalidate_cache",
    _MESSAGE_TYPE_WATCH_SCHEMA_CHANGED = "watch_schema_changed",
    _MESSAGE_TYPE_SET_CONN_INFO = "set_conn_info",
    _MESSAGE_TYPE_MUTATE_SYNC_OBJECT = "mutate_sync_object",
    _MESSAGE_TYPE_FETCH_CURSOR = "fetch_cursor",
    _MESSAGE_TYPE_CREATE_QUERY_SNAPSHOT = "create_query_snapshot";

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

  Future<bool> pullChanges({List<String>? schemas}) async {
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
      unsynced.addAll(SyncController.SYNC_SCHEMAS.map((e) => SchemaVersion(e, 0)));
    }

    unsynced = unsynced.where((element) => SyncSchema.byName(element.schemaName)?.remoteReadable ?? false).toList();

    if (schemas != null) {
      unsynced = unsynced.where((element) => schemas.contains(element)).toList();
    }

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

  Future<_WatchSchemasReply> watchSchemas(_WatchSchemasMessage ask) async {
    var prevNum = getSchemaVersion(ask.schemas);
    final initial = prevNum;
    final subscription = _localRepository.onSchemaChanged().listen((event) {
      if (ask.schemas.contains(event.schemaName)) {
        var newNum = getSchemaVersion(ask.schemas);
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

    return _WatchSchemasReply(initial, cancel.sendPort);
  }

  Future<MutationResult> handleMutationRequest(_MutateSyncObjectMessage req) async {
    final syncObject = req.getObject();
    if (syncObject == null) {
      return MutationResult.localFailure(message: "Invalid object");
    }
    final schema = syncObject.getSchema();

    if (!schema.localMutationHandler.canHandleMutationType(req.op)) {
      return MutationResult.localFailure(message: "Can't handle ${req.op} for schema ${schema.schemaName}");
    }

    final mutData = await schema.localMutationHandler.createMutation(_localRepository, syncObject, req.op);
    if (mutData == null) {
      return MutationResult.localFailure(message: "Couldn't create changeset for ${syncObject.getSchema().schemaName}");
    }

    if (mutData.isEmpty) {
      //return MutationResult(SyncStorageType.Remote)..setSuccessful(true);
    }

    var needsRemoteSync = true;
    if (req.op == SyncObjectMutationType.Delete && _localRepository.isLocalId(syncObject.getId())) {
      // records which need to be deleted and which exist just locally need to be deleted from the local db without sending them to the server
      needsRemoteSync = false;
    }

    if (needsRemoteSync && schema.remoteMutationHandler.canHandleMutationType(req.op)) {
      if (_connectivityInfo.networkingEnabled) {
        Result<List<RemoteSchemaChangelog>>? remoteResult;
        try {
          remoteResult =
              await schema.remoteMutationHandler.submitMutation(mutData, _localRepository, _remoteRepository);
        } on RemoteMutationException catch (e) {
          return e.asMutationResult();
        }

        if (remoteResult.isSuccess) {
          final res = await schema.remoteMutationHandler
              .applyRemoteMutationResult(mutData, remoteResult.body ?? [], _localRepository);
          _applyMutationResult(res);
          return res;
        }

        return MutationResult.remoteFailure(message: remoteResult.errorMessage ?? "Unexpected failure");
      } else {
        // enqueue this mutation for submitting it later
        _localRepository.dbConn
            .insert(SyncPendingRemoteMutation.TABLE_NAME, mutData.toDbValues(), onConflict: OnConflictDo.Replace);
      }
    }

    final res = await schema.localMutationHandler.applyLocalMutation(mutData, _localRepository);
    _applyMutationResult(res);
    return res;
  }

  bool _applyMutationResult(MutationResult mutResult) {
    if (!mutResult.isSuccessful) {
      return false;
    }

    final affectedSchemas = Set<String>();

    final success = _localRepository.dbConn.runInTransaction((tx) {
      final replacements = mutResult.replacements;
      if (replacements != null && mutResult.sourceStorage == SyncStorageType.Remote) {
        for (final repl in mutResult.replacements!) {
          final parentSchema = repl.object.getSchema();

          tx.insert(
              "_sync_object_resolved_ids",
              {
                "schema_name": parentSchema.schemaName,
                "local_id": repl.prevId,
                "remote_id": repl.newId,
              },
              onConflict: OnConflictDo.Replace);

          affectedSchemas.add(parentSchema.schemaName);

          final idCol = parentSchema.idColumn;
          if (idCol == null) {
            continue;
          }

          // update the id in the database
          tx.update(parentSchema.schemaName, {idCol.name: repl.newId}, {idCol.name: repl.prevId});
          // mark this record as updated
          // mutResult.add(SyncObjectMutationType.Update, repl.object);

          // update all objects which reference this object with the new id
          SyncController.SYNC_SCHEMAS.forEach((schemaName) {
            final depSchema = SyncSchema.byNameStrict(schemaName);
            depSchema.columns.where((col) => col.referenceOf?.schemaName == parentSchema.schemaName).forEach((depCol) {
              tx.update(depSchema.tableName, {depCol.name: repl.newId}, {depCol.name: repl.prevId});
              affectedSchemas.add(depSchema.schemaName);
            });
          });
        }
      }

      final deleted = mutResult.deleted;
      if (deleted != null) {
        // collect all deleted objects and any other object which references this object
        final delRecords = LinkedHashMap<String, SyncObject>();
        for (final del in mutResult.deleted!) {
          _collectReferencesToObject(del, delRecords, tx);
        }

        final schemaDels = HashMap<String, List<int>>();
        for (final rec in delRecords.values) {
          final schema = rec.getSchema();
          final recId = rec.getId();
          if (recId == 0) {
            continue;
          }
          if (!schemaDels.containsKey(schema.schemaName)) {
            schemaDels[schema.schemaName] = [recId];
          } else {
            schemaDels[schema.schemaName]!.add(recId);
          }
        }

        for (final schemaName in schemaDels.keys) {
          final schema = SyncSchema.byNameStrict(schemaName);
          tx.execute(
              "delete from ${schema.tableName} where ${schema.idColumn!.name} in (${schemaDels[schemaName]!.join(", ")})");
          affectedSchemas.add(schemaName);
        }
      }

      final List<SyncObject> upserts = [];
      if (mutResult.created != null) {
        upserts.addAll(mutResult.created!);
      }
      if (mutResult.updated != null) {
        upserts.addAll(mutResult.updated!);
      }

      if (upserts.isNotEmpty) {
        for (final rec in upserts) {
          final schema = rec.getSchema();
          tx.insert(schema.tableName, rec.dumpValues(includeId: true).toMap(), onConflict: OnConflictDo.Replace);
          affectedSchemas.add(schema.schemaName);
        }
      }

      return true;
    });

    if (!success) {
      affectedSchemas.clear();
      return false;
    }

    affectedSchemas.forEach((schemaName) {
      _localRepository.localSchemaInfos[schemaName]?.invalidateVersion();
    });
    return true;
  }

  _collectReferencesToObject(SyncObject rec, Map<String, SyncObject> dest, DbConn db) {
    if (rec.isNewRecord()) {
      return;
    }
    final recSchema = rec.getSchema();
    final key = "${recSchema.schemaName}-${rec.id}";
    if (dest.containsKey(key)) {
      return;
    }
    dest[key] = rec;

    SyncController.SYNC_SCHEMAS.forEach((childSchemaName) {
      final childSchema = SyncSchema.byNameStrict(childSchemaName);
      childSchema.columns
          .where((col) =>
              col.referenceOf?.schemaName == recSchema.schemaName &&
              col.referenceOf?.onDeleteReferenceDo == OnDeleteReferenceDo.Delete)
          .forEach((depCol) {
        db
            .select("select * from $childSchemaName where ${depCol.name}=?", [rec.id])
            .map((e) => childSchema.instantiate(e.toMap()))
            .forEach((childRec) {
              _collectReferencesToObject(childRec, dest, db);
            });
      });
    });
  }

  int getSchemaVersion(List<String> schemaNames) {
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
        final ask = message.args as _WatchSchemasMessage;
        return await watchSchemas(ask);
      case _MESSAGE_TYPE_SET_CONN_INFO:
        _connectivityInfo.setValue(message.args as int);
        return;
      case _MESSAGE_TYPE_MUTATE_SYNC_OBJECT:
        final msg = message.args as _MutateSyncObjectMessage;
        return await handleMutationRequest(msg);
      case _MESSAGE_TYPE_FETCH_CURSOR:
        final msg = message.args as _FetchCursorMessage;

        final cursor = this._localRepository.dbConn.select(msg.sql, msg.args);
        return cursor.toJson();
      case _MESSAGE_TYPE_CREATE_QUERY_SNAPSHOT:
        final msg = message.args as _CreateQuerySnapshotMessage;
        final tableName = "__temp_${uuidGenV4().replaceAll("-", "")}";
        final sql = "create table $tableName as ${msg.sql}";
        this._localRepository.dbConn.execute(sql, msg.args);
        return tableName;
      default:
        throw Exception("SyncEngineBackEnd doesn't know how to handle ${message.type}");
    }
  }
}

// runs in the main isolate and schedules tasks to run in a background isloate
class SyncController extends TaskRunner {
  static final _instances = HashMap<int, SyncController>();

  static SyncController current() {
    return SyncController.forAccount(AuthController.instance.currentAccount!);
  }

  static SyncController forAccount(UserAccount account) {
    if (!_instances.containsKey(account.id)) {
      _instances[account.id] = SyncController(account);
    }
    return _instances[account.id]!;
  }

  static const SYNC_SCHEMAS = [
    Coil.SCHEMA_NAME,
    Location.SCHEMA_NAME,
    Product.SCHEMA_NAME,
    ProductLocation.SCHEMA_NAME,
    MachineColumnSale.SCHEMA_NAME,
    Pack.SCHEMA_NAME,
    PackEntry.SCHEMA_NAME,
    Restock.SCHEMA_NAME,
    RestockEntry.SCHEMA_NAME,
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

  SyncController(this._userAccount) {
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

  Future<Stream<int>> createSchemaChangedStream(List<String> schemaNames) async {
    final p = ReceivePort();
    _WatchSchemasReply reply =
        await this.exec(_MESSAGE_TYPE_WATCH_SCHEMA_CHANGED, args: _WatchSchemasMessage(p.sendPort, schemaNames));

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

  Future<MutationResult> upsertObject(SyncObject obj) async {
    final op = obj.isNewRecord() ? SyncObjectMutationType.Create : SyncObjectMutationType.Update;
    return await mutateObject(obj, op);
  }

  Future<MutationResult> mutateObject(SyncObject obj, SyncObjectMutationType op) async {
    return await this.exec(_MESSAGE_TYPE_MUTATE_SYNC_OBJECT, args: _MutateSyncObjectMessage.forObject(obj, op));
  }

  Future<SqlResultSet> select(String sql, {List<Object>? args}) async {
    final Map<String, dynamic> cursorJson =
        await this.exec(_MESSAGE_TYPE_FETCH_CURSOR, args: _FetchCursorMessage(sql, args ?? List.empty()));
    return SqlResultSet.fromJson(cursorJson);
  }

  final _snapshotMux = Mutex();
  final _snapshots = HashMap<String, String>();

  Future<SqlSelectQueryBuilder> createQuerySnapshot(SqlSelectQueryBuilder queryBuilder) async {
    final query = queryBuilder.build();
    final queryKey = query.signature();

    await _snapshotMux.acquire();

    try {
      if (!_snapshots.containsKey(queryKey)) {
        _snapshots[queryKey] = await this
            .exec(_MESSAGE_TYPE_CREATE_QUERY_SNAPSHOT, args: _CreateQuerySnapshotMessage(query.sql, query.args ?? []));
      }

      return queryBuilder.forSnapshot(_snapshots[queryKey]!);
    } finally {
      _snapshotMux.release();
    }
  }

  Future<dynamic> loadObject(SyncSchema schema, {required int id}) async {
    final res =
        (await select("select * from ${schema.tableName} where ${schema.idColumn?.name ?? "id"}=?", args: [id]));

    if (res.length == 1) {
      return schema.instantiate(res.first.toMap());
    }
    return null;
  }

  Future<String> getLocalDatabasePath() async {
    final docsPath = (await getApplicationDocumentsDirectory()).path;
    final databasesPath = path.join(docsPath, "databases");
    await Directory(databasesPath).create(recursive: true);

    return path.join(databasesPath, "data_${_userAccount.envName}_${_userAccount.id}.db");
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

class _WatchSchemasMessage {
  final SendPort notifyPort;
  final List<String> schemas;

  _WatchSchemasMessage(this.notifyPort, this.schemas);
}

class _WatchSchemasReply {
  final SendPort cancelPort;
  final int dataVersion;

  _WatchSchemasReply(this.dataVersion, this.cancelPort);
}

class _MutateSyncObjectMessage {
  final Map<String, dynamic> syncObjectAttrs;
  final String schemaName;
  final SyncObjectMutationType op;

  _MutateSyncObjectMessage(this.schemaName, this.op, this.syncObjectAttrs);

  static _MutateSyncObjectMessage forObject(SyncObject object, SyncObjectMutationType op) {
    return _MutateSyncObjectMessage(object.getSchema().schemaName, op, object.toJson());
  }

  SyncObject? getObject() {
    return SyncSchema.byName(this.schemaName)?.instantiate(this.syncObjectAttrs);
  }
}

class _FetchCursorMessage {
  final String sql;
  final List<Object?> args;

  _FetchCursorMessage(this.sql, this.args);
}

class _CreateQuerySnapshotMessage {
  final String sql;
  final List<Object?> args;

  _CreateQuerySnapshotMessage(this.sql, this.args);
}

//  {"pack":{"ts":1626771132580,"data":[{"product_id":88894,"column_id":727228,"unitcount":8},{"product_id":88922,"column_id":727229,"unitcount":8}]}}
class PackRequest {}

// {"stock":{"ts":1626771276617,"data":[{"product_id":88894,"column_id":727228,"unitcount":9},{"product_id":88922,"column_id":727229,"unitcount":9}]}}
class StockRequest {}

class ProductCoilInventory {
  final int productId, coilId, unitCount;

  static ProductCoilInventory fromJson(Map<String, dynamic> json) {
    return ProductCoilInventory(productId: json["product_id"], coilId: json["column_id"], unitCount: json["unitcount"]);
  }

  ProductCoilInventory({required this.productId, required this.coilId, required this.unitCount});

  Map<String, dynamic> toJson() {
    return {
      "product_id": productId,
      "column_id": coilId,
      "unitcount": unitCount,
    };
  }
}
