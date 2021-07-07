import 'package:vgbnd/sync/schema.dart';

import 'base_model.dart';

class Coil extends BaseModel<Coil> {
  static const String SCHEMA_NAME = 'columns';

  static final schema = SyncDbSchema<Coil>(SCHEMA_NAME, allocate: () => Coil(), columns: [
    SyncDbColumn.id(),
    SyncDbColumn(
      "column_name",
      readAttribute: (dest) => dest.columnName,
      assignAttribute: (value, key, dest) {
        dest.columnName = value.getValue(key) ?? dest.columnName;
      },
    ),
    SyncDbColumn(
      "planogram_id",
      readAttribute: (dest) => dest.planogramId,
      assignAttribute: (value, key, dest) {
        dest.planogramId = value.getValue(key) ?? dest.planogramId;
      },
    ),
    SyncDbColumn(
      "product_id",
      readAttribute: (dest) => dest.productId,
      assignAttribute: (value, key, dest) {
        dest.productId = value.getValue(key) ?? dest.productId;
      },
    ),
    SyncDbColumn(
      "location_id",
      readAttribute: (dest) => dest.locationId,
      assignAttribute: (value, key, dest) {
        dest.locationId = value.getValue(key) ?? dest.locationId;
      },
    ),
    SyncDbColumn(
      "display_name",
      readAttribute: (dest) => dest.displayName,
      assignAttribute: (value, key, dest) {
        dest.displayName = value.getValue(key) ?? dest.displayName;
      },
    ),
    SyncDbColumn(
      "last_fill",
      readAttribute: (dest) => dest.lastFill,
      assignAttribute: (value, key, dest) {
        dest.lastFill = value.getValue(key) ?? dest.lastFill;
      },
    ),
    SyncDbColumn(
      "capacity",
      readAttribute: (dest) => dest.capacity,
      assignAttribute: (value, key, dest) {
        dest.capacity = value.getValue(key) ?? dest.capacity;
      },
    ),
    SyncDbColumn(
      "max_capacity",
      readAttribute: (dest) => dest.maxCapacity,
      assignAttribute: (value, key, dest) {
        dest.maxCapacity = value.getValue(key) ?? dest.maxCapacity;
      },
    ),
    SyncDbColumn(
      "last_visit",
      readAttribute: (dest) => dest.lastVisit,
      assignAttribute: (value, key, dest) {
        dest.lastVisit = value.getValue(key) ?? dest.lastVisit;
      },
    ),
    SyncDbColumn(
      "tray_id",
      readAttribute: (dest) => dest.trayId,
      assignAttribute: (value, key, dest) {
        dest.trayId = value.getValue(key) ?? dest.trayId;
      },
    ),
    SyncDbColumn(
      "coil_notes",
      readAttribute: (dest) => dest.coilNotes,
      assignAttribute: (value, key, dest) {
        dest.coilNotes = value.getValue(key) ?? dest.coilNotes;
      },
    ),
    SyncDbColumn(
      "set_price",
      readAttribute: (dest) => dest.setPrice,
      assignAttribute: (value, key, dest) {
        dest.setPrice = value.getValue(key) ?? dest.setPrice;
      },
    ),
    SyncDbColumn(
      "sts_coils",
      readAttribute: (dest) => dest.stsCoils,
      assignAttribute: (value, key, dest) {
        dest.stsCoils = value.getValue(key) ?? dest.stsCoils;
      },
    ),
    SyncDbColumn(
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
  SyncDbSchema<Coil> getSchema() {
    return schema;
  }
}

