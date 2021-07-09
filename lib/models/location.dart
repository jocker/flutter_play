import 'package:vgbnd/sync/schema.dart';

import '../sync/sync_object.dart';

class Location extends SyncObject<Location> {
  static const SchemaName SCHEMA_NAME = 'locations';

  static final schema = SyncSchema<Location>(SCHEMA_NAME, allocate: () => Location(), columns: [
    SyncColumn.id(),
    SyncColumn(
      "location_name",
      assignAttribute: (value, key, dest) {
        dest.locationName = value.getValue(key) ?? dest.locationName;
      },
      readAttribute: (dest) {
        return dest.locationName;
      },
    ),
    SyncColumn(
      "location_address",
      assignAttribute: (value, key, dest) {
        dest.address = value.getValue(key) ?? dest.address;
      },
      readAttribute: (dest) {
        return dest.address;
      },
    ),
    SyncColumn(
      "location_address2",
      assignAttribute: (value, key, dest) {
        dest.addressSecondary = value.getValue(key) ?? dest.addressSecondary;
      },
      readAttribute: (dest) {
        return dest.addressSecondary;
      },
    ),
    SyncColumn(
      "location_city",
      assignAttribute: (value, key, dest) {
        dest.city = value.getValue(key) ?? dest.city;
      },
      readAttribute: (dest) {
        return dest.city;
      },
    ),
    SyncColumn(
      "location_state",
      assignAttribute: (value, key, dest) {
        dest.state = value.getValue(key) ?? dest.state;
      },
      readAttribute: (dest) {
        return dest.state;
      },
    ),
    SyncColumn(
      "location_zip",
      assignAttribute: (value, key, dest) {
        dest.postalCode = value.getValue(key) ?? dest.postalCode;
      },
      readAttribute: (dest) {
        return dest.postalCode;
      },
    ),
    SyncColumn(
      "location_type",
      assignAttribute: (value, key, dest) {
        dest.type = value.getValue(key) ?? dest.type;
      },
      readAttribute: (dest) {
        return dest.type;
      },
    ),
    SyncColumn(
      "last_visit",
      assignAttribute: (value, key, dest) {
        dest.lastVisit = value.getValue(key) ?? dest.lastVisit;
      },
      readAttribute: (dest) {
        return dest.lastVisit;
      },
    ),
    SyncColumn(
      "planogram_id",
      assignAttribute: (value, key, dest) {
        dest.planogramId = value.getValue(key) ?? dest.planogramId;
      },
      readAttribute: (dest) {
        return dest.planogramId;
      },
    ),
    SyncColumn(
      "flags",
      assignAttribute: (value, key, dest) {
        dest.flags = value.getValue(key) ?? dest.flags;
      },
      readAttribute: (dest) {
        return dest.flags;
      },
    ),
    SyncColumn(
      "lat",
      assignAttribute: (value, key, dest) {
        dest.latitude = value.getValue(key) ?? dest.latitude;
      },
      readAttribute: (dest) {
        return dest.latitude;
      },
    ),
    SyncColumn(
      "long",
      assignAttribute: (value, key, dest) {
        dest.longitude = value.getValue(key) ?? dest.longitude;
      },
      readAttribute: (dest) {
        return dest.longitude;
      },
    ),
    SyncColumn(
      "account",
      assignAttribute: (value, key, dest) {
        dest.account = value.getValue(key) ?? dest.account;
      },
      readAttribute: (dest) {
        return dest.account;
      },
    ),
    SyncColumn(
      "route",
      assignAttribute: (value, key, dest) {
        dest.route = value.getValue(key) ?? dest.route;
      },
      readAttribute: (dest) {
        return dest.route;
      },
    ),
    SyncColumn(
      "location_make",
      assignAttribute: (value, key, dest) {
        dest.make = value.getValue(key) ?? dest.make;
      },
      readAttribute: (dest) {
        return dest.route;
      },
    ),
    SyncColumn(
      "location_model",
      assignAttribute: (value, key, dest) {
        dest.model = value.getValue(key) ?? dest.model;
      },
      readAttribute: (dest) {
        return dest.model;
      },
    ),
    SyncColumn(
      "machine_serial",
      assignAttribute: (value, key, dest) {
        dest.machineSerial = value.getValue(key) ?? dest.machineSerial;
      },
      readAttribute: (dest) {
        return dest.machineSerial;
      },
    ),
    SyncColumn(
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
  SyncSchema<Location> getSchema() {
    return schema;
  }
}
