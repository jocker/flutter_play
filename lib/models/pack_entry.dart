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
          referenceOf: ReferenceOfSchema(Product.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete),
          readAttribute: (dest) => dest.productId,
          assignAttribute: (value, key, dest) {
            dest.productId = value.getValue(key) ?? dest.productId;
          },
        ),
        SyncColumn(
          "location_id",
          referenceOf: ReferenceOfSchema(Location.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete),
          readAttribute: (dest) => dest.locationId,
          assignAttribute: (value, key, dest) {
            dest.locationId = value.getValue(key) ?? dest.locationId;
          },
        ),
        SyncColumn(
          "column_id",
          referenceOf: ReferenceOfSchema(Coil.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete),
          readAttribute: (dest) => dest.coilId,
          assignAttribute: (value, key, dest) {
            dest.coilId = value.getValue(key) ?? dest.coilId;
          },
        ),
        SyncColumn(
          "pack_id",
          referenceOf: ReferenceOfSchema(Pack.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete),
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
