import 'package:vgbnd/models/base_model.dart';
import 'package:vgbnd/sync/_local_repository.dart';
import 'package:vgbnd/sync/constants.dart';
import 'package:vgbnd/sync/record_changelog.dart';
import 'package:vgbnd/sync/value_holder.dart';

abstract class RecordPersistence<T> {}

class SchemaPersist<T extends BaseModel> {
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

  Future<RecordChangelog?> getRecordChangelog(LocalRepository local, T instance, SyncRecordOp op) async {
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
}
