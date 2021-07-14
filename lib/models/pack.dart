import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

class Pack extends SyncObject<Pack> {
  static const SchemaName SCHEMA_NAME = 'packs';

  int? locationId;
  int? restockId;

  static final schema = SyncSchema<Pack>(SCHEMA_NAME,
      syncOps: [SyncSchemaOp.RemoteWrite],
      allocate: () => Pack(),
      columns: [
        SyncColumn.id(),
        SyncColumn(
          "location_id",
          readAttribute: (dest) => dest.locationId,
          assignAttribute: (value, key, dest) {
            dest.locationId = value.getValue(key) ?? dest.locationId;
          },
        ),
        SyncColumn(
          "restock_id",
          readAttribute: (dest) => dest.restockId,
          assignAttribute: (value, key, dest) {
            dest.restockId = value.getValue(key) ?? dest.restockId;
          },
        ),
      ]);

  @override
  SyncSchema<Pack> getSchema() {
    return schema;
  }
}
