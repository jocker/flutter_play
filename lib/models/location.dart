import 'package:vgbnd/sync/schema.dart';

import 'base_model.dart';

class Location extends BaseModel<Location> {
  static const String SCHEMA_NAME = 'locations';

  static final schema = SyncDbSchema<Location>(SCHEMA_NAME, allocate: () => Location(), columns: [
    SyncDbColumn.id(),
    SyncDbColumn(
      "location_name",
      assignAttribute: (value, key, dest) {
        dest.locationName = value.getValue(key) ?? dest.locationName;
      },
      readAttribute: (dest) {
        return dest.locationName;
      },
    ),
    SyncDbColumn(
      "location_address",
      assignAttribute: (value, key, dest) {
        dest.address = value.getValue(key) ?? dest.address;
      },
      readAttribute: (dest) {
        return dest.address;
      },
    ),
    SyncDbColumn(
      "location_address2",
      assignAttribute: (value, key, dest) {
        dest.addressSecondary = value.getValue(key) ?? dest.addressSecondary;
      },
      readAttribute: (dest) {
        return dest.addressSecondary;
      },
    ),
    SyncDbColumn(
      "location_city",
      assignAttribute: (value, key, dest) {
        dest.city = value.getValue(key) ?? dest.city;
      },
      readAttribute: (dest) {
        return dest.city;
      },
    ),
    SyncDbColumn(
      "location_state",
      assignAttribute: (value, key, dest) {
        dest.state = value.getValue(key) ?? dest.state;
      },
      readAttribute: (dest) {
        return dest.state;
      },
    ),
    SyncDbColumn(
      "location_zip",
      assignAttribute: (value, key, dest) {
        dest.postalCode = value.getValue(key) ?? dest.postalCode;
      },
      readAttribute: (dest) {
        return dest.postalCode;
      },
    ),
    SyncDbColumn(
      "location_type",
      assignAttribute: (value, key, dest) {
        dest.type = value.getValue(key) ?? dest.type;
      },
      readAttribute: (dest) {
        return dest.type;
      },
    ),
    SyncDbColumn(
      "last_visit",
      assignAttribute: (value, key, dest) {
        dest.lastVisit = value.getValue(key) ?? dest.lastVisit;
      },
      readAttribute: (dest) {
        return dest.lastVisit;
      },
    ),
    SyncDbColumn(
      "planogram_id",
      assignAttribute: (value, key, dest) {
        dest.planogramId = value.getValue(key) ?? dest.planogramId;
      },
      readAttribute: (dest) {
        return dest.planogramId;
      },
    ),
    SyncDbColumn(
      "flags",
      assignAttribute: (value, key, dest) {
        dest.flags = value.getValue(key) ?? dest.flags;
      },
      readAttribute: (dest) {
        return dest.flags;
      },
    ),
    SyncDbColumn(
      "lat",
      assignAttribute: (value, key, dest) {
        dest.latitude = value.getValue(key) ?? dest.latitude;
      },
      readAttribute: (dest) {
        return dest.latitude;
      },
    ),
    SyncDbColumn(
      "long",
      assignAttribute: (value, key, dest) {
        dest.longitude = value.getValue(key) ?? dest.longitude;
      },
      readAttribute: (dest) {
        return dest.longitude;
      },
    ),
    SyncDbColumn(
      "account",
      assignAttribute: (value, key, dest) {
        dest.account = value.getValue(key) ?? dest.account;
      },
      readAttribute: (dest) {
        return dest.account;
      },
    ),
    SyncDbColumn(
      "route",
      assignAttribute: (value, key, dest) {
        dest.route = value.getValue(key) ?? dest.route;
      },
      readAttribute: (dest) {
        return dest.route;
      },
    ),
    SyncDbColumn(
      "location_make",
      assignAttribute: (value, key, dest) {
        dest.make = value.getValue(key) ?? dest.make;
      },
      readAttribute: (dest) {
        return dest.route;
      },
    ),
    SyncDbColumn(
      "location_model",
      assignAttribute: (value, key, dest) {
        dest.model = value.getValue(key) ?? dest.model;
      },
      readAttribute: (dest) {
        return dest.model;
      },
    ),
    SyncDbColumn(
      "machine_serial",
      assignAttribute: (value, key, dest) {
        dest.machineSerial = value.getValue(key) ?? dest.machineSerial;
      },
      readAttribute: (dest) {
        return dest.machineSerial;
      },
    ),
    SyncDbColumn(
      "cardreader_serial",
      assignAttribute: (value, key, dest) {
        dest.cardReaderSerial = value.getValue(key) ?? dest.cardReaderSerial;
      },
      readAttribute: (dest) {
        return dest.cardReaderSerial;
      },
    )
  ]);

  String? locationName;
  String? address;
  String? addressSecondary;
  String? city;
  String? state;
  String? postalCode;
  int? type;
  DateTime? lastVisit;
  int? planogramId;
  int? flags;
  double? latitude;
  double? longitude;
  String? account;
  String? route;
  String? make;
  String? model;
  String? machineSerial;
  String? cardReaderSerial;

  @override
  SyncDbSchema<Location> getSchema() {
    return schema;
  }
}
