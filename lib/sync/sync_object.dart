import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/value_holder.dart';

abstract class SyncObject<T> {
  int? id;

  bool isNewRecord() {
    return this.id == null;
  }

  int getId() {
    return id ?? 0;
  }

  SyncDbSchema<T> getSchema();

  PrimitiveValueHolder dumpValues() {
    return getSchema().dumpObject(this as T);
  }

  PrimitiveValueHolder diffFrom(SyncObject<T> other) {
    return dumpValues().diffFrom(other.dumpValues());
  }
}

class SyncObjectIdentifier {
  final String schemaName;
  final int id;

  SyncObjectIdentifier(this.schemaName, this.id);
}
