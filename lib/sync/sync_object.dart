import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/value_holder.dart';

import '../../ext.dart';

abstract class SyncObject<T extends SyncObject<T>> {
  static const _SCHEMA_ATTR_NAME = "__schema";

  static T? fromJson<T extends SyncObject<T>>(Map<String, dynamic> values) {
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

  String? getDisplayName() {
    return getSchema().columns.firstWhereOrNull((col) => col.isDisplayNameColumn)?.readAttribute(this as T);
  }

  SyncSchema<T> getSchema();

  assignValues(Map<String, dynamic>? values) {
    if (values != null) {
      getSchema().assignValues(this as T, values);
    }
  }

  PrimitiveValueHolder dumpValues({bool? includeId}) {
    final values = getSchema().dumpObject(this as T);

    if (includeId != true) {
      values.remove(getSchema().idColumn?.name ?? "");
    }

    return values;
  }

  PrimitiveValueHolder diffFrom(SyncObject<T> other) {
    return dumpValues().diffFrom(other.dumpValues());
  }

  Map<String, dynamic> toJson() {
    final values = dumpValues(includeId: true).toMap();
    values[_SCHEMA_ATTR_NAME] = getSchema().schemaName;
    return values;
  }
}
