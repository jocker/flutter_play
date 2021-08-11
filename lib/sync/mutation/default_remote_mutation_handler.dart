import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/log.dart';
import 'package:vgbnd/sync/mutation/mutation.dart';
import 'package:vgbnd/sync/repository/local_repository.dart';
import 'package:vgbnd/sync/repository/remote_repository.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_pending_remote_mutation.dart';

import '../../ext.dart';
import '../sync_object.dart';
import 'mutation_handlers.dart';

class DefaultRemoteMutationHandler<T extends SyncObject<T>> with RemoteMutationHandler<T> {
  static addChangelog(MutationResult mutResult, RemoteSchemaChangelog changelog, LocalRepository localRepo) {
    final schema = SyncSchema.byName(changelog.schemaName);
    if (schema == null) {
      return;
    }

    int? maxRemoteID;

    final idColName = schema.idColumn?.name;
    if (idColName != null) {
      maxRemoteID =
          localRepo.dbConn.selectValue<int?>("select coalesce( (select max($idColName) from ${schema.tableName}), 0)");
    }

    for (var entry in changelog.entries()) {
      final syncObject = entry.toSyncObject();
      if (syncObject == null) {
        continue;
      }

      if (entry.isDeleted == true) {
        mutResult.add(SyncObjectMutationType.Delete, syncObject);
      }

      if (maxRemoteID != null && maxRemoteID < syncObject.getId()) {
        mutResult.add(SyncObjectMutationType.Create, syncObject);
      } else {
        mutResult.add(SyncObjectMutationType.Update, syncObject);
      }
    }
  }

  MutationResult _processRemoteChangelog(List<RemoteSchemaChangelog> changelogs, LocalRepository localRepo) {
    final mutResult = MutationResult(SyncStorageType.Remote);

    for (var changelog in changelogs) {
      DefaultRemoteMutationHandler.addChangelog(mutResult, changelog, localRepo);
    }

    mutResult.setSuccessful(true);
    return mutResult;
  }

  @override
  Future<MutationResult> applyRemoteMutationResult(SyncPendingRemoteMutation mutData,
      List<RemoteSchemaChangelog> remoteChangelogs, LocalRepository localRepo) async {
    final mutResult = _processRemoteChangelog(remoteChangelogs, localRepo);
    switch (mutData.mutationType) {
      case SyncObjectMutationType.Create:
        final createdOfType =
            mutResult.created?.where((element) => element.getSchema().schemaName == mutData.schemaName);
        if (createdOfType?.length == 1) {
          final replacement = createdOfType!.first;
          if (localRepo.isLocalId(replacement.getId())) {
            mutResult.replace(mutData.objectId, replacement.getId(), replacement);
            mutResult.created?.remove(replacement);
          }
        } else {
          logger.e(
              "[Create] expecting exactly 1 record of type ${mutData.schemaName}. Got ${createdOfType?.length ?? 0}");
        }

        break;
      case SyncObjectMutationType.Delete:
        final deletedCount = mutResult.deleted
            ?.where((element) =>
                element.getSchema().schemaName == mutData.schemaName && element.getId() == mutData.objectId)
            .length;
        if (deletedCount != 1) {
          logger.e("[Delete] expecting exactly 1 record of type ${mutData.schemaName}. Got $deletedCount");
        }
        break;
      case SyncObjectMutationType.Update:
        final updatedCount = mutResult.updated
            ?.where((element) =>
                element.getSchema().schemaName == mutData.schemaName && element.getId() == mutData.objectId)
            .length;
        if (updatedCount != 1) {
          logger.e("[Update] expecting exactly 1 record of type ${mutData.schemaName}. Got $updatedCount");
        }
        break;
      default:
        break;
    }

    return mutResult;
  }

  @override
  Future<Result<List<RemoteSchemaChangelog>>> submitMutation(
      SyncPendingRemoteMutation mutData, LocalRepository localRepo, RemoteRepository remoteRepo) async {
    switch (mutData.mutationType) {
      case SyncObjectMutationType.Create:
        final reqPayload =
            _replaceResolvedDependenciesStrict(mutData.schemaName, localRepo, mutData.getDataForCreate()!.data);

        return remoteRepo.api.createSchemaObject(mutData.schemaName, reqPayload);
      case SyncObjectMutationType.Update:
        final updateMutData = mutData.getDataForUpdate()!;

        final reqPayload = [
          {
            "ts": updateMutData.snapshot.ts,
            "type": 1,
            "data": _replaceResolvedDependenciesStrict(mutData.schemaName, localRepo, updateMutData.snapshot.data)
          }
        ];

        for (final rev in updateMutData.revisions) {
          reqPayload.add({
            "ts": rev.ts,
            "type": 2,
            "data": _replaceResolvedDependenciesStrict(mutData.schemaName, localRepo, rev.data),
          });
        }

        return remoteRepo.api.updateSchemaObject(mutData.schemaName, mutData.objectId, reqPayload);
      default:
        throw UnimplementedError("missing implementation");
    }
  }

  @override
  Future<bool> hasUnresolvedDependencies(SyncPendingRemoteMutation mutData, LocalRepository localRepo) async {
    if (mutData.mutationType == SyncObjectMutationType.Delete) {
      return false;
    }
    Map<String, dynamic> valuesToCheck;

    switch (mutData.mutationType) {
      case SyncObjectMutationType.Create:
        valuesToCheck = mutData.getDataForCreate()!.data;
        break;
      case SyncObjectMutationType.Update:
        valuesToCheck = mutData.getDataForUpdate()!.mergedRevisionData();
        break;
      default:
        return await super.hasUnresolvedDependencies(mutData, localRepo);
    }

    for (var writeableCol in SyncSchema.byNameStrict(mutData.schemaName).remoteReferenceColumns) {
      final colValue = readPrimitive<int>(valuesToCheck[writeableCol.name]);
      if (colValue != null && localRepo.isLocalId(colValue)) {
        return true;
      }
    }

    return false;
  }

  Map<String, dynamic> _replaceResolvedDependenciesStrict(
      String schemaName, LocalRepository localRepo, Map<String, dynamic> values) {
    if (!_replaceResolvedDependencies(schemaName, localRepo, values)) {
      throw UnimplementedError("_replaceResolvedDependenciesStrict");
    }
    return values;
  }

  bool _replaceResolvedDependencies(String schemaName, LocalRepository localRepo, Map<String, dynamic> values) {
    final schema = SyncSchema.byNameStrict(schemaName);
    for (var col in schema.remoteReferenceColumns) {
      if (values.containsKey(col.name)) {
        final id = readPrimitive<int>(values);
        if (id == null) {
          continue;
        }
        if (localRepo.isLocalId(id)) {
          final resolvedId = localRepo.getResolvedId(schemaName, id);
          if (resolvedId != null && !localRepo.isLocalId(resolvedId)) {
            values[col.name] = resolvedId;
          } else {
            return false;
          }
        }
      }
    }
    return true;
  }
}
