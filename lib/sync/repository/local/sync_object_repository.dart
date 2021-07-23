import 'package:vgbnd/data/db.dart';

import '../../../constants/constants.dart';
import '../../schema.dart';
import '../../sync_object.dart';

mixin SyncObjectDatabaseStorage {
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
    final obj = schema.allocate();
    if (loadFirstObjectInto(obj, where, db: db)) {
      return obj;
    }
    return null;
  }

  bool loadFirstObjectInto(SyncObject obj, Map<String, dynamic> where, {DbConn? db}) {
    final schema = obj.getSchema();
    final query = StringBuffer("select * from ${schema.tableName}");
    final List<dynamic> params = [];

    _appendWhere(query, params, where);
    query.write(" limit 1");

    final values = (db ?? getDb()).selectOne(query.toString(), params);
    if (values == null) {
      return false;
    }
    schema.assignValues(obj, values);
    return true;
  }

  _appendWhere(StringBuffer query, List<dynamic> queryParams, Map<String, dynamic>? whereParams) {
    if (whereParams != null) {
      var isFirst = true;
      for (var k in whereParams.keys) {
        query.write(isFirst ? " where " : " and ");
        isFirst = false;

        query..write(k)..write(" =? ");
        queryParams.add(whereParams[k]);
      }
    }
  }

  bool insertObject(SyncObject obj, {DbConn? db, OnConflictDo? onConflict, List<String>? columns, bool? reload}) {
    final schema = obj.getSchema();
    final idCol = schema.idColumn;

    final insertValues = obj.dumpValues(includeId: false).toMap();

    if (columns != null) {
      for (final key in (insertValues.keys.toList()..removeWhere((colName) => !columns.contains(colName)))) {
        insertValues.remove(key);
      }
    }

    if (db == null) {
      db = getDb();
    }

    var id = 0;
    if (idCol != null) {
      insertValues.remove(idCol);
      id = getNextInsertId(schema.schemaName);
      insertValues[idCol.name] = id;
    }

    db.insert(schema.schemaName, insertValues, onConflict: onConflict);
    final rowId = db.lastInsertRowId;
    if (db.affectedRowsCount == 1 && rowId != 0) {
      if (reload != false) {
        loadFirstObjectInto(obj, {"rowid": rowId}, db: db);
      }
      return true;
    }
    return false;
  }

  bool update(String tableName, Map<String, dynamic> values, Map<String, dynamic> where, {DbConn? db}) {
    db ??= getDb();
    db.update(tableName, values, where);
    return db.affectedRowsCount > 0;
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

    if (values.isEmpty || updateEntry(schema, id, values, db: db)) {
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
