import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/schema.dart';


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

  static final schema = SyncDbSchema<MachineColumnSale>(SCHEMA_NAME, allocate: () => MachineColumnSale(), columns: [
    SyncDbColumn.readonly("machinecolumn"),
    SyncDbColumn.readonly("location_id", referenceOf: Location.SCHEMA_NAME),
    SyncDbColumn.readonly("unitcount"),
    SyncDbColumn.readonly("last_sale_cash_amount"),
    SyncDbColumn.readonly("last_sale_unit_count"),
    SyncDbColumn.readonly("units_sold_since"),
    SyncDbColumn.readonly("last_sale_date"),
  ]);

  @override
  SyncDbSchema<MachineColumnSale> getSchema() {
    return schema;
  }
}
