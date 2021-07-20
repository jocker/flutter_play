import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

class MachineColumnSale extends SyncObject<MachineColumnSale> {
  static const SchemaName SCHEMA_NAME = 'machine_column_sales';

  String? machineColumn;
  int? locationId;
  int? unitcount;
  double? lastSaleCashAmount;
  int? lastSaleUnitCount;
  int? unitsSoldSince;
  double? cashAmountSince;
  DateTime? lastSaleDate;

  static final schema = SyncSchema<MachineColumnSale>(SCHEMA_NAME, allocate: () => MachineColumnSale(), columns: [
    SyncColumn.readonly("machinecolumn"),
    SyncColumn.readonly("location_id",
        referenceOf: ReferenceOfSchema(Location.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete)),
    SyncColumn.readonly("unitcount"),
    SyncColumn.readonly("last_sale_cash_amount"),
    SyncColumn.readonly("last_sale_unit_count"),
    SyncColumn.readonly("units_sold_since"),
    SyncColumn.readonly("last_sale_date"),
  ]);

  @override
  SyncSchema<MachineColumnSale> getSchema() {
    return schema;
  }
}
