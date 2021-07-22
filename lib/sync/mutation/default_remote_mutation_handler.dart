
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/log.dart';
import 'package:vgbnd/sync/mutation/mutation.dart';
import 'package:vgbnd/sync/repository/local_repository.dart';
import 'package:vgbnd/sync/repository/remote_repository.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_pending_remote_mutation.dart';

import '../sync_object.dart';
import 'mutation_handlers.dart';

class DefaultRemoteMutationHandler<T extends SyncObject<T>> with RemoteMutationHandler<T> {


  MutationResult _processRemoteChangelog(List<RemoteSchemaChangelog> changelogs, DbConn dbConn) {
    final mutResult = MutationResult(SyncStorageType.Remote);

    for (var changelog in changelogs) {
      final schema = SyncSchema.byName(changelog.schemaName);
      if (schema == null) {
        continue;
      }

      int? maxRemoteID;

      final idColName = schema.idColumn?.name;
      if (idColName != null) {
        maxRemoteID =
            dbConn.selectValue<int?>("select coalesce(0, (select max($idColName}) from ${schema.tableName}))");
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

    mutResult.setSuccessful(true);
    return mutResult;
  }

  @override
  Future<MutationResult> applyRemoteMutationResult(
      SyncPendingRemoteMutation mutData, List<RemoteSchemaChangelog> remoteChangelogs, LocalRepository localRepo) async{
    final mutResult = _processRemoteChangelog(remoteChangelogs, localRepo.dbConn);
    switch (mutData.mutationType) {
      case SyncObjectMutationType.Create:
        final createdOfType =
            mutResult.created?.where((element) => element.getSchema().schemaName == mutData.schemaName);
        if (createdOfType?.length == 1) {
          final replacement = createdOfType!.first;
          mutResult.replace(mutData.objectId, replacement.getId(), replacement);
          mutResult.created?.remove(replacement);
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
      SyncPendingRemoteMutation mutData, LocalRepository localRepo, RemoteRepository remoteRepo) {
    // TODO: implement submitMutation
    throw UnimplementedError();
  }


}
