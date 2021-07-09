import 'package:vgbnd/sync/mutation/sync_object_snapshot.dart';
import 'package:vgbnd/sync/object_mutation.dart';
import 'package:vgbnd/sync/repository/_local_repository.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

import '../constants.dart';
import '../value_holder.dart';
import 'base.dart';

mixin DefaultLocalMutationHandlerMixin<T extends SyncObject<T>> {
  ensureHasIdSet(LocalRepository local, T instance) {
    final idCol = instance.getSchema().idColumn;
    if (idCol != null) {
      final id = idCol.readAttribute(instance);
      if (id == 0) {
        idCol.assignAttribute(
            PrimitiveValueHolder.fromMap({idCol.name: local.getNextInsertId(instance.getSchema().tableName)}),
            idCol.name,
            instance);
      }
    }
  }

  ObjectMutationData? createObjectMutationData(LocalRepository localRepo, T syncObj, SyncObjectMutationType op) {
    Map<String, dynamic> data = {};
    SyncObjectSnapshot? snapshot;

    switch (op) {
      case SyncObjectMutationType.Update:
        if (!syncObj.isNewRecord()) {
          final prevInstance = localRepo.loadObjectById(syncObj.getSchema(), syncObj.getId());
          if (prevInstance == null) {
            return null;
          }
          final schemaName = syncObj.getSchema().schemaName;
          data = syncObj.diffFrom(prevInstance).toMap();
          snapshot = SyncObjectSnapshot(
              schemaName: schemaName,
              objectId: syncObj.getId(),
              revNum: localRepo.getSchemaVersion(schemaName),
              data: prevInstance.dumpValues().toMap());
        } else {
          data = syncObj.dumpValues().toMap();
        }
        break;
      case SyncObjectMutationType.Delete:
        break;
      case SyncObjectMutationType.Create:
        ensureHasIdSet(localRepo, syncObj);
        data = syncObj.dumpValues().toMap();
        break;
      default:
        return null;
    }

    final idPropName = syncObj.getSchema().idColumn?.name;
    if (idPropName != null) {
      data.remove(idPropName);
    }

    final recChangelog = ObjectMutationData.fromModel(syncObj, op);
    recChangelog.data = data;
    recChangelog.snapshot = snapshot;
  }

  MutationResult applyLocalMutationForObject(ObjectMutationData mutData, LocalRepository localRepo) {
    final mutResult = MutationResult(SyncStorageType.Local);

    final schema = SyncSchema.byName(mutData.schemaName) as SyncSchema<SyncObject>?;
    if (schema == null) {
      return mutResult..setSuccessful(false);
    }

    SyncObject? rec;

    switch (mutData.operation) {
      case SyncObjectMutationType.Create:
        rec = localRepo.insertObject(schema, mutData.data!);
        break;
      case SyncObjectMutationType.Update:
        rec = localRepo.updateObject(schema, mutData.objectId, mutData.data!);
        break;
      case SyncObjectMutationType.Delete:
        rec = localRepo.loadObjectById(schema, mutData.objectId);
        if (rec != null) {
          if (!localRepo.deleteObject(schema, mutData.objectId)) {
            rec = null;
          }
        }
        break;
      default:
        break;
    }

    if (rec != null) {
      mutResult.add(mutData.operation, rec);
      mutResult.setSuccessful(true);
    } else {
      mutResult.setSuccessful(false);
    }
    return mutResult;
  }
}

class BaseLocalMutationHandler<T extends SyncObject<T>> extends LocalMutationHandler<T>
    with DefaultLocalMutationHandlerMixin<T> {
  final List<SyncObjectMutationType> _supportedMutationTypes;

  BaseLocalMutationHandler(this._supportedMutationTypes);

  @override
  bool canHandleMutationType(SyncObjectMutationType t) {
    return _supportedMutationTypes.contains(t);
  }

  @override
  Future<MutationResult> applyLocalMutation(ObjectMutationData mutData, LocalRepository localRepo) async {
    return applyLocalMutationForObject(mutData, localRepo);
  }

  @override
  Future<ObjectMutationData?> createMutation(LocalRepository localRepo, T instance, SyncObjectMutationType op) async {
    return createObjectMutationData(localRepo, instance, op);
  }
}
