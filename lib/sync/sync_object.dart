import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/value_holder.dart';

abstract class SyncObject<T extends SyncObject<T>> {
  static const _SCHEMA_ATTR_NAME = "__schema";

  static SyncObject<T>? fromJson<T extends SyncObject<T>>(Map<String, dynamic> values) {
    final schema = SyncSchema.byName(values[_SCHEMA_ATTR_NAME] ?? "");
    if (schema == null) {
      return null;
    }
    return schema.instantiate(values);
  }

  int? id;

  bool isNewRecord() {
    return this.id == null;
  }

  int getId() {
    return id ?? 0;
  }

  SyncSchema<T> getSchema();

  PrimitiveValueHolder dumpValues() {
    return getSchema().dumpObject(this as T);
  }

  PrimitiveValueHolder diffFrom(SyncObject<T> other) {
    return dumpValues().diffFrom(other.dumpValues());
  }

  Map<String, dynamic> toJson() {
    final values = dumpValues().toMap();
    values[_SCHEMA_ATTR_NAME] = getSchema().schemaName;
    return values;
  }
}
