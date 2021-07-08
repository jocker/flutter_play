import 'package:vgbnd/models/base_model.dart';
import 'package:vgbnd/sync/_local_repository.dart';
import 'package:vgbnd/sync/_remote_repository.dart';
import 'package:vgbnd/sync/persistence/base.dart';
import 'package:vgbnd/sync/record_changelog.dart';
import 'package:vgbnd/sync/schema.dart';

import '../constants.dart';
import '../value_holder.dart';

mixin X<T extends BaseModel<T>> {
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

  RecordChangelog? createRecordChangelogForOp(LocalRepository local, T instance, SyncRecordOp op) {
    Map<String, dynamic> data = {};

    switch (op) {
      case SyncRecordOp.Update:
        if (!instance.isNewRecord()) {
          final prevInstance = local.loadById(instance.getSchema(), instance.getId());
          if (prevInstance == null) {
            return null;
          }
          data = instance.diffFrom(prevInstance).toMap();
        } else {
          data = instance.dumpValues().toMap();
        }
        break;
      case SyncRecordOp.Delete:
        break;
      case SyncRecordOp.Create:
        ensureHasIdSet(local, instance);
        data = instance.dumpValues().toMap();
        break;
      default:
        return null;
    }

    final idPropName = instance.getSchema().idColumn?.name;
    if (idPropName != null) {
      data.remove(idPropName);
    }

    final recChangelog = RecordChangelog.fromModel(instance, op);
    recChangelog.data = data;
  }

  bool applyLocalChangelogForOp(RecordChangelog changelog, LocalRepository localRepo, SyncRecordOp op) {
    final schema = SyncDbSchema.byName(changelog.schemaName);
    if (schema == null) {
      return false;
    }
    switch (op) {
      case SyncRecordOp.Create:
        final rec = localRepo.insert(schema, changelog.data!);
        return rec != null;
      case SyncRecordOp.Update:
        final rec = localRepo.update(schema, changelog.recordId, changelog.data!);
        return rec != null;
      case SyncRecordOp.Delete:
        return localRepo.delete(schema, changelog.recordId);
      default:
        return false;
    }
  }
}

class _ModelLocalPersistence<T extends BaseModel<T>> extends LocalPersistence<T> with X<T> {
  final SyncRecordOp _op;

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


class CreateModelLocalPersistence<T extends BaseModel<T>> extends _ModelLocalPersistence<T>{
  CreateModelLocalPersistence() : super(SyncRecordOp.Create);
}

class UpdateModelLocalPersistence<T extends BaseModel<T>> extends _ModelLocalPersistence<T>{
  UpdateModelLocalPersistence() : super(SyncRecordOp.Update);
}

class DeleteModelLocalPersistence<T extends BaseModel<T>> extends _ModelLocalPersistence<T>{
  DeleteModelLocalPersistence() : super(SyncRecordOp.Delete);
}



class _ModelRemotePersistence<T extends BaseModel<T>> extends RemotePersistence<T>{
  @override
  Future<bool> applyRemoteChangelogResult(RecordChangelog localChangelog, RemoteSubmitResult remoteResult, LocalRepository localRepo) {
    throw UnimplementedError();
  }

  @override
  Future<RemoteSubmitResult> submitChangelog(RecordChangelog changelog, LocalRepository localRepo, RemoteRepository remoteRepo) {

    throw UnimplementedError();
  }

}