import 'package:vgbnd/sync/persistence/sync_object_snapshor.dart';
import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/sync/_local_repository.dart';
import 'package:vgbnd/sync/_remote_repository.dart';
import 'package:vgbnd/sync/persistence/base.dart';
import 'package:vgbnd/sync/record_changelog.dart';
import 'package:vgbnd/sync/schema.dart';

import '../constants.dart';
import '../value_holder.dart';

mixin X<T extends SyncObject<T>> {
  ensureHasIdSet(LocalRepository local, T instance) {
    final idCol = instance.getSchema().idColumn;
    if (idCol != null) {
      final id = idCol.readAttribute(instance);
      if (id == 0) {
        idCol.assignAttribute(
            PrimitiveValueHolder.fromMap({idCol.name: local.nextLocalId(instance.getSchema().tableName)}),
            idCol.name,
            instance);
      }
    }
  }

  ensureHasSnapshot(String schema, int objectId) {}

  RecordChangelog? createRecordChangelogForOp(LocalRepository localRepo, T syncObj, SyncObjectOp op) {
    Map<String, dynamic> data = {};
    SyncObjectSnapshot? snapshot;

    switch (op) {
      case SyncObjectOp.Update:
        if (!syncObj.isNewRecord()) {
          final prevInstance = localRepo.loadById(syncObj.getSchema(), syncObj.getId());
          if (prevInstance == null) {
            return null;
          }
          final schemaName = syncObj.getSchema().schemaName;
          data = syncObj.diffFrom(prevInstance).toMap();
          snapshot = SyncObjectSnapshot(
              schemaName: schemaName,
              recordId: syncObj.getId(),
              revNum: localRepo.schemaVersion(schemaName),
              data: prevInstance.dumpValues().toMap());
        } else {
          data = syncObj.dumpValues().toMap();
        }
        break;
      case SyncObjectOp.Delete:
        break;
      case SyncObjectOp.Create:
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

    final recChangelog = RecordChangelog.fromModel(syncObj, op);
    recChangelog.data = data;
    recChangelog.snapshot = snapshot;
  }

  bool applyLocalChangelogForOp(RecordChangelog changelog, LocalRepository localRepo, SyncObjectOp op) {
    final schema = SyncDbSchema.byName(changelog.schemaName);
    if (schema == null) {
      return false;
    }
    switch (op) {
      case SyncObjectOp.Create:
        final rec = localRepo.insert(schema, changelog.data!);
        return rec != null;
      case SyncObjectOp.Update:
        final rec = localRepo.update(schema, changelog.recordId, changelog.data!);
        return rec != null;
      case SyncObjectOp.Delete:
        return localRepo.delete(schema, changelog.recordId);
      default:
        return false;
    }
  }
}

class _ModelLocalPersistence<T extends SyncObject<T>> extends LocalPersistence<T> with X<T> {
  final SyncObjectOp _op;

  _ModelLocalPersistence(this._op);

  @override
  Future<bool> applyLocalChangelog(RecordChangelog changelog, LocalRepository localRepo) async {
    return applyLocalChangelogForOp(changelog, localRepo, _op);
  }

  @override
  Future<RecordChangelog?> createChangelog(LocalRepository localRepo, T instance) async {
    return createRecordChangelogForOp(localRepo, instance, _op);
  }
}

class CreateModelLocalPersistence<T extends SyncObject<T>> extends _ModelLocalPersistence<T> {
  CreateModelLocalPersistence() : super(SyncObjectOp.Create);
}

class UpdateModelLocalPersistence<T extends SyncObject<T>> extends _ModelLocalPersistence<T> {
  UpdateModelLocalPersistence() : super(SyncObjectOp.Update);
}

class DeleteModelLocalPersistence<T extends SyncObject<T>> extends _ModelLocalPersistence<T> {
  DeleteModelLocalPersistence() : super(SyncObjectOp.Delete);
}

class _ModelRemotePersistence<T extends SyncObject<T>> extends RemotePersistence<T> {
  @override
  Future<bool> applyRemoteChangelogResult(
      RecordChangelog localChangelog, RemoteSubmitResult remoteResult, LocalRepository localRepo) {
    throw UnimplementedError();
  }

  @override
  Future<RemoteSubmitResult> submitChangelog(
      RecordChangelog changelog, LocalRepository localRepo, RemoteRepository remoteRepo) {
    throw UnimplementedError();
  }
}
