import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

class MachineColumnSale extends SyncObject<MachineColumnSale> {
  static const SchemaName SCHEMA_NAME = 'machine_column_sales';

  String? machineColumn;
  int? locationId;
  int? unitcount;
  int? productId;
  double? lastSaleCashAmount;
  int? lastSaleUnitCount;
  int? unitsSoldSince;
  double? cashAmountSince;
  DateTime? lastSaleDate;

  static final schema = SyncSchema<MachineColumnSale>(SCHEMA_NAME, allocate: () => MachineColumnSale(), columns: [
    SyncColumn(
      "machinecolumn",
      readAttribute: (dest) {
        return dest.machineColumn;
      },
      assignAttribute: (value, key, dest) {
        dest.machineColumn = value.getValue(key);
      },
    ),
    SyncColumn("product_id", readAttribute: (dest) {
      return dest.productId;
    }, assignAttribute: (value, key, dest) {
      dest.productId = value.getValue(key);
    }, referenceOf: ReferenceOfSchema(Location.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete)),
    SyncColumn("location_id", readAttribute: (dest) {
      return dest.locationId;
    }, assignAttribute: (value, key, dest) {
      dest.locationId = value.getValue(key);
    }, referenceOf: ReferenceOfSchema(Location.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete)),
    SyncColumn(
      "cash_amount_since",
      readAttribute: (dest) {
        return dest.cashAmountSince;
      },
      assignAttribute: (value, key, dest) {
        dest.cashAmountSince = value.getValue(key);
      },
    ),
    SyncColumn(
      "units_sold_since",
      readAttribute: (dest) {
        return dest.unitsSoldSince;
      },
      assignAttribute: (value, key, dest) {
        dest.unitsSoldSince = value.getValue(key);
      },
    ),
    SyncColumn(
      "last_sale_cash_amount",
      readAttribute: (dest) {
        return dest.lastSaleCashAmount;
      },
      assignAttribute: (value, key, dest) {
        dest.lastSaleCashAmount = value.getValue(key);
      },
    ),
    SyncColumn(
      "last_sale_unit_count",
      readAttribute: (dest) {
        return dest.lastSaleUnitCount;
      },
      assignAttribute: (value, key, dest) {
        dest.lastSaleUnitCount = value.getValue(key);
      },
    ),
    SyncColumn(
      "last_sale_date",
      readAttribute: (dest) {
        return dest.lastSaleDate;
      },
      assignAttribute: (value, key, dest) {
        dest.lastSaleDate = value.getValue(key);
      },
    ),
  ]);

  @override
  SyncSchema<MachineColumnSale> getSchema() {
    return schema;
  }
}
