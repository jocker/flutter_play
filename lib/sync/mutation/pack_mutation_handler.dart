import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/pack_entry.dart';
import 'package:vgbnd/sync/object_mutation.dart';
import 'package:vgbnd/sync/repository/_local_repository.dart';
import 'package:vgbnd/sync/repository/_remote_repository.dart';
import 'package:vgbnd/sync/sync_object.dart';

import 'mutation.dart';

class LocalPackMutationHandler extends LocalMutationHandler<Pack> {
  @override
  Future<MutationResult> applyLocalMutation(ObjectMutationData changelog, LocalRepository localRepo) {
    switch (changelog.mutationType) {
      case SyncObjectMutationType.Create:
        return _applyLocationMutationForCreate(changelog, localRepo);
    }

    throw UnimplementedError();
  }

  Future<MutationResult> _applyLocationMutationForCreate(
      ObjectMutationData changelog, LocalRepository localRepo) async {
    final pack = Pack.fromJson(changelog.data!);
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
  Future<ObjectMutationData?> createMutation(LocalRepository localRepo, Pack pack, SyncObjectMutationType op) async {
    final data = ObjectMutationData.fromModel(pack, op);
    if (op == SyncObjectMutationType.Create) {
      data.data = pack.toJson();
    }
    return data;
  }
}

class RemotePackMutationHandler extends RemoteMutationHandler<Pack> {
  @override
  Future<MutationResult> applyRemoteMutationResult(
      ObjectMutationData mutationData, MutationResult remoteResult, LocalRepository localRepo) {
    throw UnimplementedError();
  }

  @override
  Future<MutationResult> submitMutation(
      ObjectMutationData changelog, LocalRepository localRepo, RemoteRepository remoteRepo) async {
    final pack = Pack.fromJson(changelog.data!);
    if (pack == null) {
      return MutationResult.failure(sourceStorage: SyncStorageType.Remote);
    }

    final packEntries = pack.entries;
    if (packEntries?.isEmpty ?? true) {
      return MutationResult.remoteFailure(message: "No pack entries");
    }
//  {"pack":{"ts":1626771132580,"data":[{"product_id":88894,"column_id":727228,"unitcount":8},{"product_id":88922,"column_id":727229,"unitcount":8}]}}

    final Map<String, dynamic> payload = {
      "pack": {
        "ts": changelog.revNum,
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

    throw UnimplementedError();
  }

  _assignPackEntriesIfNeeded(DbConn db, Pack pack) {
    if (pack.isNewRecord()) {
      return;
    }
    List<PackEntry> packEntries = db
        .select("select * from ${pack.getSchema().tableName} where pack_id = ?", [pack.id])
        .mapOf(PackEntry.schema)
        .toList();
  }
}
