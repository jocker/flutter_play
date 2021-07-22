import 'dart:collection';

import 'package:vgbnd/sync/mutation/mutation_handlers.dart';
import 'package:vgbnd/sync/repository/local_repository.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/sync_pending_remote_mutation.dart';

import '../../constants/constants.dart';
import '../value_holder.dart';
import 'mutation.dart';

class DefaultLocalMutationHandler<T extends SyncObject<T>> with LocalMutationHandler<T> {
  final List<SyncObjectMutationType> _supportedMutationTypes;

  DefaultLocalMutationHandler(this._supportedMutationTypes);

  @override
  bool canHandleMutationType(SyncObjectMutationType t) {
    return _supportedMutationTypes.contains(t);
  }

  @override
  Future<MutationResult> applyLocalMutation(SyncPendingRemoteMutation mutData, LocalRepository localRepo) async {
    return applyLocalMutationForObject(mutData, localRepo);
  }

  @override
  Future<SyncPendingRemoteMutation?> createMutation(
      LocalRepository localRepo, T instance, SyncObjectMutationType op) async {
    return createObjectMutationData(localRepo, instance, op);
  }

  ensureHasIdSet(LocalRepository localRepo, T syncObj) {
    final idCol = syncObj.getSchema().idColumn;
    if (idCol != null) {
      final id = idCol.readAttribute(syncObj);
      if (id == 0) {
        idCol.assignAttribute(
            PrimitiveValueHolder.fromMap({idCol.name: localRepo.getNextInsertId(syncObj.getSchema().tableName)}),
            idCol.name,
            syncObj);
      }
    }
  }

  SyncPendingRemoteMutation? createObjectMutationData(LocalRepository localRepo, T syncObj, SyncObjectMutationType op) {
    var pendingMut = SyncPendingRemoteMutation.loadForObject(syncObj, localRepo.dbConn);

    if (op == SyncObjectMutationType.Create) {
      ensureHasIdSet(localRepo, syncObj);
    }

    if (pendingMut != null) {
      // is the previous or the new mutation is a delete, the new mutation will be also a delete
      if (op == SyncObjectMutationType.Delete || pendingMut.mutationType == SyncObjectMutationType.Delete) {
        pendingMut.mutationType = SyncObjectMutationType.Delete;
        return pendingMut;
      }

      if (pendingMut.mutationType == SyncObjectMutationType.Create && op == SyncObjectMutationType.Update) {
        // replace the previous values with the new ones
        pendingMut.data = MutationDataForCreate(syncObj.dumpValues().toMap()).toDbJson();
      }

      if (pendingMut.mutationType == SyncObjectMutationType.Update && op == SyncObjectMutationType.Update) {
        final updateMutData = MutationDataForUpdate.fromDbJson(pendingMut.data!);
        final mergedValues = HashMap<String, dynamic>();
        mergedValues.addAll(updateMutData.snapshot.data);
        for (final rev in updateMutData.revisions) {
          mergedValues.addAll(rev.data);
        }
        final newRevValues = syncObj.getSchema().instantiate(mergedValues).diffFrom(syncObj).toMap();
        updateMutData.addNewRevision(newRevValues);

        pendingMut.data = updateMutData.toDbJson();
      }
    } else {
      pendingMut = SyncPendingRemoteMutation.fromModel(syncObj, op);
      switch (op) {
        case SyncObjectMutationType.Delete:
          // nothing to do for deletes
          break;
        case SyncObjectMutationType.Create:
          final values = syncObj.dumpValues().toMap();
          pendingMut.data = MutationDataForCreate(values).toDbJson();
          break;
        case SyncObjectMutationType.Update:
          final prevInstance = localRepo.loadObjectById(syncObj.getSchema(), syncObj.getId());
          if (prevInstance == null) {
            return null;
          }
          final revisionData = prevInstance.diffFrom(syncObj).toMap();
          final snapshotData = prevInstance.dumpValues().toMap();
          pendingMut.data = MutationDataForUpdate.create(snapshotData, revisionData).toDbJson();
          break;
        default:
          return null;
      }
    }

    return pendingMut;
  }

  MutationResult applyLocalMutationForObject(SyncPendingRemoteMutation mutData, LocalRepository localRepo) {
    final mutResult = MutationResult(SyncStorageType.Local);

    final schema = SyncSchema.byName(mutData.schemaName) as SyncSchema<T>?;
    if (schema == null) {
      return mutResult..setSuccessful(false);
    }

    T? rec;

    switch (mutData.mutationType) {
      case SyncObjectMutationType.Create:
        throw UnsupportedError("");
        //rec = localRepo.insertObject(schema, mutData.data!) as T;
        break;
      case SyncObjectMutationType.Update:
        rec = localRepo.updateObject(schema, mutData.objectId, mutData.data!) as T;
        break;
      case SyncObjectMutationType.Delete:
        rec = localRepo.loadObjectById(schema, mutData.objectId);
        if (rec != null) {
          if (!localRepo.deleteEntry(schema, mutData.objectId)) {
            rec = null;
          }
        }
        break;
      default:
        break;
    }

    if (rec != null) {
      mutResult.add(mutData.mutationType, rec);
      mutResult.setSuccessful(true);
    } else {
      mutResult.setSuccessful(false);
    }
    return mutResult;
  }
}

class MutationDataForCreate {
  final Map<String, dynamic> data;

  static MutationDataForCreate fromDbJson(Map<String, dynamic> json) {
    return MutationDataForCreate(json["data"]);
  }

  MutationDataForCreate(this.data);

  Map<String, dynamic> toDbJson() {
    return {
      "data": this.data,
    };
  }
}

class MutationDataForUpdate {
  final UpdateMutationDataSegment snapshot;
  final List<UpdateMutationDataSegment> revisions;

  MutationDataForUpdate(this.snapshot, this.revisions);

  static MutationDataForUpdate create(Map<String, dynamic> snapshotData, Map<String, dynamic> revisionData) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MutationDataForUpdate(
        UpdateMutationDataSegment(now, snapshotData), [UpdateMutationDataSegment(now, revisionData)]);
  }

  static MutationDataForUpdate fromDbJson(Map<String, dynamic> json) {
    final revisions = (json["revisions"] as List).map((e) {
      return UpdateMutationDataSegment.fromDbJson(e);
    }).toList();
    final snapshot = UpdateMutationDataSegment.fromDbJson(json["snapshot"]);
    return MutationDataForUpdate(snapshot, revisions);
  }

  Map<String, dynamic> toDbJson() {
    return {"snapshot": snapshot.toDbJson(), "revisions": revisions.map((e) => e.toDbJson()).toList()};
  }

  addNewRevision(Map<String, dynamic> revData) {
    this.revisions.add(UpdateMutationDataSegment(DateTime.now().millisecondsSinceEpoch, revData));
  }
}

class UpdateMutationDataSegment {
  static const int TYPE_SNAPSHOT = 1, TYPE_REVISION = 2;

  static UpdateMutationDataSegment fromDbJson(Map<String, dynamic> json) {
    return UpdateMutationDataSegment(
      json["ts"],
      json["data"],
    );
  }

  UpdateMutationDataSegment(this.ts, this.data);

  final int ts;
  final Map<String, dynamic> data;

  Map<String, dynamic> toDbJson() {
    return {
      "ts": ts,
      "data": data,
    };
  }
}
