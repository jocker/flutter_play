import 'dart:collection';

import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/sync/mutation/mutation.dart';
import 'package:vgbnd/sync/object_mutation.dart';
import 'package:vgbnd/sync/repository/_local_repository.dart';
import 'package:vgbnd/sync/repository/_remote_repository.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync.dart';

import '../sync_object.dart';

class DefaultRemoteMutationHandler<T extends SyncObject<T>> extends RemoteMutationHandler<T> {
  @override
  Future<MutationResult> applyRemoteMutationResult(
      ObjectMutationData mutationData, MutationResult remoteResult, LocalRepository localRepo) {
    final affectedSchemas = Set<String>();

    localRepo.dbConn.runInTransaction((tx) {
      final replacements = remoteResult.replacements;
      if (replacements != null) {
        for (final repl in remoteResult.replacements!) {
          final parentSchema = repl.object.getSchema();

          tx.insert(
              "_sync_object_resolved_ids",
              {
                "schema_name": parentSchema.schemaName,
                "local_id": repl.prevId,
                "remote_id": repl.newId,
              },
              onConflict: OnConflictDo.Replace);

          affectedSchemas.add(parentSchema.schemaName);

          final idCol = parentSchema.idColumn;
          if (idCol == null) {
            continue;
          }

          SyncEngine.SYNC_SCHEMAS.forEach((schemaName) {
            final depSchema = SyncSchema.byNameStrict(schemaName);
            depSchema.columns.where((col) => col.referenceOf == parentSchema.schemaName).forEach((depCol) {
              tx.update(depSchema.tableName, {depCol.name: repl.newId}, {depCol.name: repl.prevId});
              affectedSchemas.add(depSchema.schemaName);
            });
          });
        }
      }

      final deleted = remoteResult.deleted;
      if (deleted != null) {
        final delRecords = LinkedHashMap<String, SyncObject>();
        for (final del in remoteResult.deleted!) {
          _collectDependenciesOf(del, delRecords, tx);
        }

        final schemaDels = HashMap<String, List<int>>();
        for (final rec in delRecords.values) {
          final schema = rec.getSchema();
          final idCol = schema.idColumn;
          if (idCol == null) {
            continue;
          }
          final recId = idCol.readAttribute(rec);
          if (!schemaDels.containsKey(schema.schemaName)) {
            schemaDels[schema.schemaName] = [recId];
          } else {
            schemaDels[schema.schemaName]!.add(recId);
          }
        }

        for (final schemaName in schemaDels.keys) {
          final schema = SyncSchema.byNameStrict(schemaName);
          tx.execute(
              "delete from ${schema.tableName} where ${schema.idColumn!.name} in (${schemaDels[schemaName]!.join(", ")})");
          affectedSchemas.add(schemaName);
        }
      }

      final List<SyncObject> upserts = [];
      if (remoteResult.created != null) {
        upserts.addAll(remoteResult.created!);
      }
      if (remoteResult.updated != null) {
        upserts.addAll(remoteResult.updated!);
      }

      if (upserts.isNotEmpty) {
        for (final rec in upserts) {
          final schema = rec.getSchema();
          tx.insert(schema.tableName, rec.dumpValues().toMap(), onConflict: OnConflictDo.Replace);
          affectedSchemas.add(schema.schemaName);
        }
      }

      return true;
    });

    // TODO: implement applyRemoteMutationResult
    throw UnimplementedError();
  }

  @override
  Future<MutationResult> submitMutation(
      ObjectMutationData changelog, LocalRepository localRepo, RemoteRepository remoteRepo) {
    throw UnimplementedError();
  }

  _collectDependenciesOf(SyncObject rec, Map<String, SyncObject> dest, DbConn db) {
    final recSchema = rec.getSchema();
    final key = "${recSchema.schemaName}-${rec.id}";
    if (dest.containsKey(key)) {
      return;
    }
    dest[key] = rec;

    SyncEngine.SYNC_SCHEMAS.forEach((childSchemaName) {
      final childSchema = SyncSchema.byNameStrict(childSchemaName);
      childSchema.columns.where((col) => col.referenceOf == recSchema.schemaName).forEach((depCol) {
        db
            .select("select * from $childSchemaName where ${depCol.name}=?", [rec.id])
            .map((e) => childSchema.instantiate(e.toMap()))
            .forEach((childRec) {
              _collectDependenciesOf(childRec, dest, db);
            });
      });
    });
  }
}
