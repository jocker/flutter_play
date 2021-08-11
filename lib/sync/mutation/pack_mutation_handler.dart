import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/pack_entry.dart';
import 'package:vgbnd/sync/repository/local_repository.dart';
import 'package:vgbnd/sync/repository/remote_repository.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/sync_pending_remote_mutation.dart';

import 'default_local_mutation_handler.dart';
import 'default_remote_mutation_handler.dart';
import 'mutation.dart';
import 'mutation_handlers.dart';

class PackMutationHandler with LocalMutationHandler<Pack>, RemoteMutationHandler<Pack> {
  @override
  Future<MutationResult> applyLocalMutation(SyncPendingRemoteMutation changelog, LocalRepository localRepo) {
    switch (changelog.mutationType) {
      case SyncObjectMutationType.Create:
        return _applyLocationMutationForCreate(changelog, localRepo);
      case SyncObjectMutationType.Delete:
        return _applyLocationMutationForDelete(changelog, localRepo);
      default:
        throw UnimplementedError();
    }
  }

  Future<MutationResult> _applyLocationMutationForDelete(
      SyncPendingRemoteMutation mutData, LocalRepository localRepo) async {
    final packData = mutData.getDataForDelete()?.data;
    final pack = Pack.schema.instantiate(packData);

    if (pack.locationId == null) {
      return MutationResult.localFailure();
    }

    final success = localRepo.dbConn.runInTransaction((tx) {
      tx.execute("delete from packs where location_id=?", [pack.locationId]);
      tx.execute("delete from pack_entries where location_id=?", [pack.locationId]);
      return true;
    });

    return MutationResult(SyncStorageType.Local)..setSuccessful(success);
  }

  Future<MutationResult> _applyLocationMutationForCreate(
      SyncPendingRemoteMutation mutData, LocalRepository localRepo) async {
    final pack = _getPackWithEntries(mutData, localRepo);
    if (pack == null) {
      return MutationResult.failure();
    }

    final List<SyncObject> created = [];

    final success = localRepo.dbConn.runInTransaction((tx) {
      if (!localRepo.insertObject(pack, db: tx)) {
        return false;
      }
      created.add(pack);

      final entries = pack.entries;
      if (entries != null) {
        for (final entry in entries) {
          entry.locationId = pack.locationId;
          entry.packId = pack.id;
          if (!localRepo.insertObject(entry, db: tx)) {
            return false;
          }
          created.add(entry);
        }
      }

      return true;
    });

    if (!success) {
      return MutationResult.failure(sourceStorage: SyncStorageType.Local);
    }

    final res = MutationResult(SyncStorageType.Local);
    res.created = created;
    res.setSuccessful(true);

    return res;
  }

  @override
  Future<SyncPendingRemoteMutation?> createMutation(
      LocalRepository localRepo, Pack pack, SyncObjectMutationType op) async {
    final data = SyncPendingRemoteMutation.fromModel(pack, op);
    if (op == SyncObjectMutationType.Create) {
      data.data = MutationDataForCreate(pack.toJson()).toDbJson();
    } else if (op == SyncObjectMutationType.Delete) {
      data.data = MutationDataForDelete(pack.toJson()).toDbJson();
    }
    return data;
  }

  @override
  Future<Result<List<RemoteSchemaChangelog>>> submitMutation(
      SyncPendingRemoteMutation mutData, LocalRepository localRepo, RemoteRepository remoteRepo) async {
    switch (mutData.mutationType) {
      case SyncObjectMutationType.Create:
        return await _submitMutationForCreate(mutData, localRepo, remoteRepo);
      case SyncObjectMutationType.Delete:
        return await _submitMutationForDelete(mutData, localRepo, remoteRepo);
      default:
        return Result.failure("can't handle this operation");
    }
  }

  _submitMutationForDelete(
      SyncPendingRemoteMutation mutData, LocalRepository localRepo, RemoteRepository remoteRepo) async {
    final locationId = Pack.schema.instantiate(mutData.getDataForDelete()?.data).locationId;
    if (locationId == null) {
      return Result.failure("can't delete packs for this location");
    }

    final res = await remoteRepo.api
        .makeRequestForChangeset(httpMethod: HttpMethod.DELETE, urlPath: "/collections/delete_packs/$locationId");
    return res;
  }

  _submitMutationForCreate(
      SyncPendingRemoteMutation mutData, LocalRepository localRepo, RemoteRepository remoteRepo) async {
    final pack = _getPackWithEntries(mutData, localRepo);

    if (pack == null) {
      return Result.failure("");
    }

    final packEntries = pack.entries;
    if (packEntries?.isEmpty ?? true) {
      return Result.success([]);
    }
//  {"pack":{"ts":1626771132580,"data":[{"product_id":88894,"column_id":727228,"unitcount":8},{"product_id":88922,"column_id":727229,"unitcount":8}]}}

    final Map<String, dynamic> payload = {
      "pack": {
        "ts": mutData.ts,
        "data": packEntries!.map((e) {
          return {
            "product_id": e.productId,
            "column_id": e.coilId,
            "unitcount": e.unitCount,
          };
        }).toList()
      }
    };

    final res = await remoteRepo.api.postRequestForChangeset("/collections/pack/${pack.locationId}", payload);
    return res;
  }

  Pack? _getPackWithEntries(SyncPendingRemoteMutation mutData, LocalRepository localRepo) {
    final data = mutData.getDataForCreate()?.data;
    if (data == null) {
      return null;
    }
    final pack = Pack.fromJson(data);
    if (pack == null) {
      return null;
    }
    if (!pack.isNewRecord()) {
      List<PackEntry> packEntries = localRepo.dbConn
          .select("select * from ${PackEntry.schema.tableName} where pack_id = ?", [pack.id])
          .mapOf(PackEntry.schema)
          .toList();

      pack.entries = packEntries;
    }
    return pack;
  }

  @override
  Future<MutationResult> _applyDefaultRemoteMutationResult(SyncPendingRemoteMutation mutData,
      List<RemoteSchemaChangelog> remoteChangelogs, LocalRepository localRepo) async {
    final mutResult = MutationResult(SyncStorageType.Remote);
    mutResult.setSuccessful(true);

    for (final changelog in remoteChangelogs) {
      DefaultRemoteMutationHandler.addChangelog(mutResult, changelog, localRepo);
    }

    return mutResult;
  }

  Future<MutationResult> _applyRemoteMutationResultForCreate(SyncPendingRemoteMutation mutData,
      List<RemoteSchemaChangelog> remoteChangelogs, LocalRepository localRepo) async {
    final prevPack = _getPackWithEntries(mutData, localRepo)!;
    Pack? replacementPack;

    final mutResult = MutationResult(SyncStorageType.Remote);
    mutResult.setSuccessful(true);

    for (final changelog in remoteChangelogs) {
      if (changelog.schemaName == PackEntry.schema.schemaName) {
        replacementPack = Pack();
        replacementPack.entries = [];
        replacementPack.locationId = prevPack.locationId;

        for (var entry in changelog.entries()) {
          if (entry.isDeleted ?? false) {
            mutResult.addForDelete(entry.toSyncObject());
            continue;
          }
          final packEntry = entry.toSyncObject() as PackEntry;
          replacementPack.entries!.add(packEntry);
          final currentPackId = packEntry.packId ?? replacementPack.id;
          if (replacementPack.id == null) {
            replacementPack.id = currentPackId;
          } else if (replacementPack.id != currentPackId) {
            throw AssertionError("received multiple packs from remote");
          }
        }

        // mark the previous pack entries for deletion as we need to replace them with the data we just got back from the server
        if (!prevPack.isNewRecord()) {
          mutResult.addForDelete(prevPack);
          for (final entry in prevPack.entries ?? []) {
            mutResult.addForDelete(entry);
          }
        }

        mutResult.addForCreate(replacementPack);
        for (final entry in replacementPack.entries ?? []) {
          mutResult.addForCreate(entry);
        }
      } else {
        DefaultRemoteMutationHandler.addChangelog(mutResult, changelog, localRepo);
      }
    }
    return mutResult;
  }

  @override
  Future<MutationResult> applyRemoteMutationResult(SyncPendingRemoteMutation mutData,
      List<RemoteSchemaChangelog> remoteChangelogs, LocalRepository localRepo) async {
    switch (mutData.mutationType) {
      case SyncObjectMutationType.Create:
        return await _applyRemoteMutationResultForCreate(mutData, remoteChangelogs, localRepo);
      default:
        return await _applyDefaultRemoteMutationResult(mutData, remoteChangelogs, localRepo);
    }
  }
}
