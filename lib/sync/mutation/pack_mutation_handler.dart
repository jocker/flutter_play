import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/pack_entry.dart';
import 'package:vgbnd/sync/repository/local_repository.dart';
import 'package:vgbnd/sync/repository/remote_repository.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/sync_pending_remote_mutation.dart';

import 'mutation.dart';
import 'mutation_handlers.dart';

class PackMutationHandler with LocalMutationHandler<Pack>, RemoteMutationHandler<Pack> {
  @override
  Future<MutationResult> applyLocalMutation(SyncPendingRemoteMutation changelog, LocalRepository localRepo) {
    switch (changelog.mutationType) {
      case SyncObjectMutationType.Create:
        return _applyLocationMutationForCreate(changelog, localRepo);
      default:
        throw UnimplementedError();
    }
  }

  Future<MutationResult> _applyLocationMutationForCreate(
      SyncPendingRemoteMutation mutData, LocalRepository localRepo) async {
    final pack = _getPack(mutData, localRepo);
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
      data.data = pack.toJson();
    }
    return data;
  }

  @override
  Future<Result<List<RemoteSchemaChangelog>>> submitMutation(
      SyncPendingRemoteMutation mutData, LocalRepository localRepo, RemoteRepository remoteRepo) async {
    final pack = _getPack(mutData, localRepo);

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

  Pack? _getPack(SyncPendingRemoteMutation mutData, LocalRepository localRepo) {
    final data = mutData.data;
    if (data == null) {
      return null;
    }
    final pack = Pack.fromJson(data);
    if (pack == null) {
      return null;
    }
    if (!pack.isNewRecord()) {
      List<PackEntry> packEntries = localRepo.dbConn
          .select("select * from ${pack.getSchema().tableName} where pack_id = ?", [pack.id])
          .mapOf(PackEntry.schema)
          .toList();

      pack.entries = packEntries;
    }
    return pack;
  }

  @override
  Future<MutationResult> applyRemoteMutationResult(
      SyncPendingRemoteMutation mutData, List<RemoteSchemaChangelog> remoteChangelog, LocalRepository localRepo) {
    for (final entry in remoteChangelog) {}
    throw UnimplementedError();
  }
}
