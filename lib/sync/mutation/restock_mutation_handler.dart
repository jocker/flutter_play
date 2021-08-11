import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/pack_entry.dart';
import 'package:vgbnd/models/restock.dart';
import 'package:vgbnd/models/restock_entry.dart';
import 'package:vgbnd/sync/mutation/mutation.dart';
import 'package:vgbnd/sync/mutation/mutation_handlers.dart';
import 'package:vgbnd/sync/repository/local_repository.dart';
import 'package:vgbnd/sync/repository/remote_repository.dart';
import 'package:vgbnd/sync/sync_pending_remote_mutation.dart';

import '../sync_object.dart';
import 'default_local_mutation_handler.dart';
import 'default_remote_mutation_handler.dart';

class RestockMutationHandler with LocalMutationHandler<Restock>, RemoteMutationHandler<Restock> {
  @override
  Future<SyncPendingRemoteMutation?> createMutation(
      LocalRepository localRepo, Restock restock, SyncObjectMutationType op) async {
    final data = SyncPendingRemoteMutation.fromModel(restock, op);
    if (op == SyncObjectMutationType.Create) {
      data.data = MutationDataForCreate(restock.toJson()).toDbJson();
    } else {
      return null;
    }
    return data;
  }

  @override
  Future<MutationResult> applyLocalMutation(SyncPendingRemoteMutation mutData, LocalRepository localRepo) async {
    final restock = _getRestockWithEntries(mutData, localRepo);
    if (restock == null) {
      return MutationResult.failure();
    }

    final List<SyncObject> created = [];
    final List<SyncObject> updated = [];

    final success = localRepo.dbConn.runInTransaction((tx) {
      if (!localRepo.insertObject(restock, db: tx)) {
        return false;
      }
      created.add(restock);

      final entries = restock.entries;
      if (entries != null) {
        for (final entry in entries) {
          entry.locationId = restock.locationId;
          entry.restockId = restock.id;
          if (!localRepo.insertObject(entry, db: tx)) {
            return false;
          }
          created.add(entry);
        }
      }

      tx.execute("update ${Pack.schema.tableName} set restock_id=? where location_id=? and restock_id=0",
          [restock.id, restock.locationId]);
      tx.execute("update ${PackEntry.schema.tableName} set restock_id=? where location_id=? and restock_id=0",
          [restock.id, restock.locationId]);

      final packs = localRepo.dbConn
          .select("select * from ${Pack.schema.tableName} where restock_id=?", [restock.id]).mapOf(Pack.schema);
      final packEntries = localRepo.dbConn.select(
          "select * from ${PackEntry.schema.tableName} where restock_id=?", [restock.id]).mapOf(PackEntry.schema);

      updated.addAll(packs);
      updated.addAll(packEntries);

      return true;
    });

    if (!success) {
      return MutationResult.failure(sourceStorage: SyncStorageType.Local);
    }

    final res = MutationResult(SyncStorageType.Local);
    res.created = created;
    res.updated = updated;
    res.setSuccessful(true);

    return res;
  }

  @override
  Future<MutationResult> applyRemoteMutationResult(SyncPendingRemoteMutation mutData,
      List<RemoteSchemaChangelog> remoteChangelogs, LocalRepository localRepo) async {
    final mutResult = MutationResult(SyncStorageType.Remote);

    final restock = _getRestockWithEntries(mutData, localRepo);
    if (restock == null) {
      // shouldn't ever happen
      mutResult.setFailure(errorsMessages: {"base": "Invalid restock"});
      return mutResult;
    }

    mutResult.setSuccessful(true);

    for (final changelog in remoteChangelogs) {
      DefaultRemoteMutationHandler.addChangelog(mutResult, changelog, localRepo);
    }

    // mark all packs for this location for deletion
    // restock_id may be 0 as well - means the pack was created while the app was in offline and the current stock is submitted when the app is online
    final packs = localRepo.dbConn.select(
        "select * from ${Pack.schema.tableName} where location_id=? and restock_id in(0, ?)",
        [restock.locationId, restock.id]).mapOf(Pack.schema);
    final packEntries = localRepo.dbConn.select(
        "select * from ${PackEntry.schema.tableName} where location_id=? and restock_id in(0, ?)",
        [restock.locationId, restock.id]).mapOf(PackEntry.schema);

    for (final rec in packs) {
      mutResult.addForDelete(rec);
    }

    for (final rec in packEntries) {
      mutResult.addForDelete(rec);
    }

    if (!restock.isNewRecord()) {
      mutResult.addForDelete(restock);
      final entries = restock.entries;
      if (entries != null) {
        for (final entry in entries) {
          mutResult.addForDelete(entry);
        }
      }
    }

    return mutResult;
  }

  @override
  Future<Result<List<RemoteSchemaChangelog>>> submitMutation(
      SyncPendingRemoteMutation mutData, LocalRepository localRepo, RemoteRepository remoteRepo) async {
    final restock = _getRestockWithEntries(mutData, localRepo);

    if (restock == null) {
      return Result.failure("");
    }

    final restockEntries = restock.entries;
    if (restockEntries?.isEmpty ?? true) {
      return Result.success([]);
    }
//curl -H "Content-Type: application/json" -X POST -d '{ "stock":{"ts":1463935093108, "data":[{"column_id":527983, "product_id":527983, "unitcount":7}]}}' localhost:3000/api/public/collections/pack_restock/23358

    final Map<String, dynamic> payload = {
      "stock": {
        "ts": mutData.ts,
        "data": restockEntries!.map((e) {
          return {
            "product_id": e.productId,
            "column_id": e.coilId,
            "unitcount": e.unitCount,
          };
        }).toList()
      }
    };

    final res =
        await remoteRepo.api.postRequestForChangeset("/collections/pack_restock/${restock.locationId}", payload);
    return res;
  }

  Restock? _getRestockWithEntries(SyncPendingRemoteMutation mutData, LocalRepository localRepo) {
    final data = mutData.getDataForCreate()?.data;
    if (data == null) {
      return null;
    }
    final restock = Restock.fromJson(data);
    if (restock == null) {
      return null;
    }
    if (!restock.isNewRecord()) {
      List<RestockEntry> restockEntries = localRepo.dbConn
          .select("select * from ${RestockEntry.schema.tableName} where restock_id = ?", [restock.id])
          .mapOf(RestockEntry.schema)
          .toList();

      restock.entries = restockEntries;
    }
    return restock;
  }
}
