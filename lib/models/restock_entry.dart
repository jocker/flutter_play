import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/sync/mutation/mutation_handlers.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

import 'coil.dart';
import 'location.dart';

class RestockEntry extends SyncObject<RestockEntry> {
  static const SchemaName SCHEMA_NAME = 'restock_entries';

  static final schema = SyncSchema<RestockEntry>(SCHEMA_NAME, localMutationHandler: LocalMutationHandler.empty(),
      remoteMutationHandler: RemoteMutationHandler.empty(),
      syncOps: [SyncSchemaOp.RemoteNone],
      allocate: () => RestockEntry(),
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

  @override
  SyncSchema<RestockEntry> getSchema() {
    return schema;
  }

  int? productId;
  int? locationId;
  int? coilId;
  int? restockId;
  int? unitCount;
}
