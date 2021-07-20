import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/sync/schema.dart';

import '../sync/sync_object.dart';

class Coil extends SyncObject<Coil> {
  static const SchemaName SCHEMA_NAME = 'columns';

  static final schema = SyncSchema<Coil>(SCHEMA_NAME,
      allocate: () => Coil(), columns: [
    SyncColumn.id(),
    SyncColumn(
      "column_name",
      readAttribute: (dest) => dest.columnName,
      assignAttribute: (value, key, dest) {
        dest.columnName = value.getValue(key) ?? dest.columnName;
      },
    ),
    SyncColumn(
      "planogram_id",
      readAttribute: (dest) => dest.planogramId,
      assignAttribute: (value, key, dest) {
        dest.planogramId = value.getValue(key) ?? dest.planogramId;
      },
    ),
    SyncColumn(
      "product_id",
      referenceOf: ReferenceOfSchema(Product.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Nothing),
      readAttribute: (dest) => dest.productId,
      assignAttribute: (value, key, dest) {
        dest.productId = value.getValue(key) ?? dest.productId;
      },
    ),
    SyncColumn(
      "location_id",
      referenceOf: ReferenceOfSchema(Location.SCHEMA_NAME),
      readAttribute: (dest) => dest.locationId,
      assignAttribute: (value, key, dest) {
        dest.locationId = value.getValue(key) ?? dest.locationId;
      },
    ),
    SyncColumn(
      "display_name",
      readAttribute: (dest) => dest.displayName,
      assignAttribute: (value, key, dest) {
        dest.displayName = value.getValue(key) ?? dest.displayName;
      },
    ),
    SyncColumn(
      "last_fill",
      readAttribute: (dest) => dest.lastFill,
      assignAttribute: (value, key, dest) {
        dest.lastFill = value.getValue(key) ?? dest.lastFill;
      },
    ),
    SyncColumn(
      "capacity",
      readAttribute: (dest) => dest.capacity,
      assignAttribute: (value, key, dest) {
        dest.capacity = value.getValue(key) ?? dest.capacity;
      },
    ),
    SyncColumn(
      "max_capacity",
      readAttribute: (dest) => dest.maxCapacity,
      assignAttribute: (value, key, dest) {
        dest.maxCapacity = value.getValue(key) ?? dest.maxCapacity;
      },
    ),
    SyncColumn(
      "last_visit",
      readAttribute: (dest) => dest.lastVisit,
      assignAttribute: (value, key, dest) {
        dest.lastVisit = value.getValue(key) ?? dest.lastVisit;
      },
    ),
    SyncColumn(
      "tray_id",
      readAttribute: (dest) => dest.trayId,
      assignAttribute: (value, key, dest) {
        dest.trayId = value.getValue(key) ?? dest.trayId;
      },
    ),
    SyncColumn(
      "coil_notes",
      readAttribute: (dest) => dest.coilNotes,
      assignAttribute: (value, key, dest) {
        dest.coilNotes = value.getValue(key) ?? dest.coilNotes;
      },
    ),
    SyncColumn(
      "set_price",
      readAttribute: (dest) => dest.setPrice,
      assignAttribute: (value, key, dest) {
        dest.setPrice = value.getValue(key) ?? dest.setPrice;
      },
    ),
    SyncColumn(
      "sts_coils",
      readAttribute: (dest) => dest.stsCoils,
      assignAttribute: (value, key, dest) {
        dest.stsCoils = value.getValue(key) ?? dest.stsCoils;
      },
    ),
    SyncColumn(
      "active",
      readAttribute: (dest) => dest.active,
      assignAttribute: (value, key, dest) {
        dest.active = value.getValue(key) ?? dest.active;
      },
    ),
  ]);

  String? columnName;
  int? planogramId;
  int? productId;
  int? locationId;
  String? displayName;
  int? lastFill;
  int? capacity;
  int? maxCapacity;
  DateTime? lastVisit;
  int? trayId;
  String? coilNotes;
  int? setPrice;
  String? stsCoils;
  bool? active;


  @override
  SyncSchema<Coil> getSchema() {
    return schema;
  }
}

