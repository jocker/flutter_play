import 'package:vgbnd/data/db.dart';

import '../constants.dart';
import '../schema.dart';
import '../sync_object.dart';

mixin SyncObjectRepository {
  DbConn getDb();

  int getNextInsertId(String schemaName);

  T? loadObjectById<T extends SyncObject<T>>(SyncSchema<T> schema, int id, {DbConn? db}) {
    final idColName = schema.idColumn?.name;
    if (idColName == null) {
      return null;
    }

    return loadFirstObjectBy(schema, {idColName: id}, db: db ?? getDb());
  }

  T? loadFirstObjectBy<T extends SyncObject<T>>(SyncSchema<T> schema, Map<String, dynamic> where, {DbConn? db}) {
    List<String> wheres = [];
    List<dynamic> params = [];

    if (db == null) {
      db = getDb();
    }

    for (var k in where.keys) {
      wheres.add("$k=?");
      params.add(where[k]);
    }

    final values = db.selectOne("select * from ${schema.tableName} where ${wheres.join(" and ")} limit 1", params);
    if (values == null) {
      return null;
    }

    final instance = schema.instantiate(values);

    return instance;
  }

  int insertValues(SyncSchema schema, Map<String, dynamic> values, {DbConn? db, OnConflictDo? onConflict}) {
    if (db == null) {
      db = getDb();
    }

    var id = 0;
    final idCol = schema.idColumn;
    if (idCol != null) {
      values.remove(idCol);
      id = getNextInsertId(schema.schemaName);
      values[idCol.name] = id;
    }

    db.insert(schema.schemaName, values, onConflict: onConflict);
    final rowId = db.lastInsertRowId;
    if (db.affectedRowsCount == 1 && rowId != 0) {
      return rowId;
    }
    return 0;
  }

  T? insertObject<T extends SyncObject<T>>(SyncSchema<T> schema, Map<String, dynamic> values,
      {DbConn? db, OnConflictDo? onConflict}) {
    final rowId = insertValues(schema, values, db: db, onConflict: onConflict);

    if (rowId != 0) {
      return loadFirstObjectBy(schema, {"rowid": rowId}, db: db);
    }
    return null;
  }

  bool updateEntry(SyncSchema schema, int id, Map<String, dynamic> values, {DbConn? db}) {
    if (db == null) {
      db = getDb();
    }

    final idCol = schema.idColumn?.name;
    if (idCol == null) {
      return false;
    }

    db.update(schema.tableName, values, {idCol: id});
    return db.affectedRowsCount == 1;
  }

  T? updateObject<T extends SyncObject<T>>(SyncSchema<T> schema, int id, Map<String, dynamic> values, {DbConn? db}) {
    if (db == null) {
      db = getDb();
    }

    if (updateEntry(schema, id, values, db: db)) {
      return loadObjectById(schema, id, db: db);
    }
    return null;
  }

  bool deleteEntry(SyncSchema schema, int id, {DbConn? db}) {
    if (db == null) {
      db = getDb();
    }
    final idCol = schema.idColumn?.name;
    if (idCol == null) {
      return false;
    }

    db.execute("delete from ${schema.tableName} where $idCol=?", [id]);

    return db.affectedRowsCount == 1;
  }

  SyncObjectPersistenceState getObjectPersistenceState(SyncObject model) {
    final idCol = model.getSchema().idColumn;
    if (idCol != null) {
      final int id = idCol.readAttribute(model);
      if (isLocalId(id)) {
        return SyncObjectPersistenceState.LocalOnly;
      } else if (id > 0) {
        return SyncObjectPersistenceState.RemoteAndLocal;
      }
    }
    return SyncObjectPersistenceState.Unknown;
  }

  bool isLocalId(int id) {
    return id < 0;
  }
}
