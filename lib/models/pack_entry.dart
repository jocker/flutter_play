import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

class PackEntry extends SyncObject<PackEntry> {
  static const SchemaName SCHEMA_NAME = 'pack_entries';

  static final schema = SyncSchema<PackEntry>(SCHEMA_NAME,
      syncOps: [SyncSchemaOp.RemoteRead],
      allocate: () => PackEntry(),
      columns: [
        SyncColumn.id(),
        SyncColumn(
          "product_id",
          referenceOf: Product.SCHEMA_NAME,
          readAttribute: (dest) => dest.productId,
          assignAttribute: (value, key, dest) {
            dest.productId = value.getValue(key) ?? dest.productId;
          },
        ),
        SyncColumn(
          "location_id",
          referenceOf: Location.SCHEMA_NAME,
          readAttribute: (dest) => dest.locationId,
          assignAttribute: (value, key, dest) {
            dest.locationId = value.getValue(key) ?? dest.locationId;
          },
        ),
        SyncColumn(
          "column_id",
          referenceOf: Coil.SCHEMA_NAME,
          readAttribute: (dest) => dest.coilId,
          assignAttribute: (value, key, dest) {
            dest.coilId = value.getValue(key) ?? dest.coilId;
          },
        ),
        SyncColumn(
          "pack_id",
          referenceOf: Pack.SCHEMA_NAME,
          readAttribute: (dest) => dest.packId,
          assignAttribute: (value, key, dest) {
            dest.packId = value.getValue(key) ?? dest.packId;
          },
        ),
        SyncColumn(
          "restock_id",
          readAttribute: (dest) => dest.restockId,
          assignAttribute: (value, key, dest) {
            dest.restockId = value.getValue(key) ?? dest.restockId;
          },
        ),
        SyncColumn(
          "unitcount",
          readAttribute: (dest) => dest.unitCount,
          assignAttribute: (value, key, dest) {
            dest.unitCount = value.getValue(key) ?? dest.unitCount;
          },
        ),
      ]);

  int? productId;
  int? locationId;
  int? coilId;
  int? packId;
  int? restockId;
  int? unitCount;

  @override
  SyncSchema<PackEntry> getSchema() {
    return schema;
  }
}
