import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/value_holder.dart';

abstract class BaseModel<T> {
  int? id;

  bool isNewRecord() {
    return this.id == null;
  }

  SyncDbSchema<T> getSchema();

  PrimitiveValueHolder dumpValues(){
    return getSchema().dumpObject(this as T);
  }
}
