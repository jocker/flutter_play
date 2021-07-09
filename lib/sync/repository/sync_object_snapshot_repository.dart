import 'package:vgbnd/data/db.dart';
import 'package:vgbnd/sync/mutation/sync_object_snapshot.dart';

import '../schema.dart';

mixin SyncObjectSnapshotRepository {
  DbConn getDb();

  SyncObjectSnapshot? loadLatestSnapshot(SyncSchema schema, int id) {
    final dbValues = getDb().selectOne(
        "select * from ${SyncObjectSnapshot.TABLE_NAME} where schema_name=? and object_id=? order by rev_num desc limit 1");
    if (dbValues == null) {
      return null;
    }

    return SyncObjectSnapshot.fromDbValues(dbValues);
  }

  clearSnapshots(SyncSchema schema, int id) {
    getDb().execute(
        "delete from ${SyncObjectSnapshot.TABLE_NAME} where schema_name=? and object_id=?", [schema.schemaName, id]);
  }

  saveSnapshot(SyncObjectSnapshot snapshot) {
    getDb().insert(SyncObjectSnapshot.TABLE_NAME, snapshot.toSqlValues(), onConflict: OnConflictDo.Ignore);
  }
}
