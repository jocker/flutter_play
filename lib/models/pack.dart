import 'package:vgbnd/models/base_model.dart';
import 'package:vgbnd/sync/constants.dart';
import 'package:vgbnd/sync/schema.dart';

class Pack extends BaseModel<Pack> {
  static const SchemaName SCHEMA_NAME = 'packs';

  int? locationId;
  int? restockId;

  static final schema = SyncDbSchema<Pack>(SCHEMA_NAME,
      syncOps: [SyncSchemaOp.RemoteWrite],
      allocate: () => Pack(),
      columns: [
        SyncDbColumn.id(),
        SyncDbColumn(
          "location_id",
          readAttribute: (dest) => dest.locationId,
          assignAttribute: (value, key, dest) {
            dest.locationId = value.getValue(key) ?? dest.locationId;
          },
        ),
        SyncDbColumn(
          "restock_id",
          readAttribute: (dest) => dest.restockId,
          assignAttribute: (value, key, dest) {
            dest.restockId = value.getValue(key) ?? dest.restockId;
          },
        ),
      ]);

  @override
  SyncDbSchema<Pack> getSchema() {
    return schema;
  }
}
