import 'package:vgbnd/data/db.dart';

import '../constants.dart';
import '../schema.dart';
import '../sync_object.dart';
import '../value_holder.dart';

mixin SyncObjectRepository{

  DbConn getDb();
  int getNextInsertId(String schemaName);

  T? loadObjectById<T>(SyncSchema<T> schema, int id) {
    final idColName = schema.idColumn?.name;
    if (idColName == null) {
      return null;
    }

    return loadFirstObjectBy(schema, {idColName: id});
  }

  T? loadFirstObjectBy<T>(SyncSchema<T> schema, Map<String, dynamic> where) {
    List<String> wheres = [];
    List<String> params = [];

    for (var k in where.keys) {
      wheres.add("$k=?");
      params.add(where[k]);
    }

    final values = getDb().selectOne("select * from ${schema.tableName} where ${wheres.join(" and ")} limit 1", params);
    if (values == null) {
      return null;
    }

    final holder = PrimitiveValueHolder.fromMap(values);

    final instance = schema.allocate();

    schema.columns.forEach((col) {
      col.assignAttribute(holder, col.name, instance);
    });

    return instance;
  }

  T? insertObject<T>(SyncSchema<T> schema, Map<String, dynamic> values) {
    var id = 0;
    final idCol = schema.idColumn;
    if (idCol != null) {
      values.remove(idCol);
      id = getNextInsertId(schema.schemaName);
      values[idCol.name] = id;
    }
    getDb().insert(schema.schemaName, values);
    final rowId = getDb().lastInsertRowId;
    if (getDb().affectedRowsCount == 1 && rowId > 0) {
      return loadFirstObjectBy(schema, {"rowid": rowId});
    }
    return null;
  }

  T? updateObject<T>(SyncSchema<T> schema, int id, Map<String, dynamic> values) {
    final idCol = schema.idColumn?.name;
    if (idCol == null) {
      return null;
    }
    getDb().update(schema.tableName, values, {idCol: id});
    if (getDb().affectedRowsCount == 1) {
      return loadObjectById(schema, id);
    }
    return null;
  }

  bool deleteObject<T>(SyncSchema<T> schema, int id) {
    final idCol = schema.idColumn?.name;
    if (idCol == null) {
      return false;
    }

    getDb().execute("delete from ${schema.tableName} where $idCol=?", [id]);

    return getDb().affectedRowsCount == 1;
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