import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/mutation/pack_mutation_handler.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

import 'pack_entry.dart';

class Pack extends SyncObject<Pack> {
  static const SchemaName SCHEMA_NAME = 'packs';

  int? locationId;
  int? restockId;

  List<PackEntry>? entries;

  static Pack? fromJson(Map<String, dynamic> values) {
    final pack = SyncObject.fromJson<Pack>(values);
    if (pack != null) {
      if (values["_pack_entries"] != null) {
        pack.entries = (values["_pack_entries"] as List).map((e) => SyncObject.fromJson<PackEntry>(e)!).toList();
      }
    }

    return pack;
  }

  static final schema = SyncSchema<Pack>(SCHEMA_NAME,
      syncOps: [SyncSchemaOp.RemoteWrite],
      localMutationHandler: LocalPackMutationHandler(),
      remoteMutationHandler: RemotePackMutationHandler(),
      allocate: () => Pack(),
      columns: [
        SyncColumn.id(),
        SyncColumn(
          "location_id",
          referenceOf: Location.SCHEMA_NAME,
          readAttribute: (dest) => dest.locationId,
          assignAttribute: (value, key, dest) {
            dest.locationId = value.getValue(key) ?? dest.locationId;
          },
        ),
        SyncColumn(
          "restock_id",
          readAttribute: (dest) => dest.restockId,
          assignAttribute: (value, key, dest) {
            dest.restockId = value.getValue(key) ?? dest.restockId;
          },
        ),
      ]);

  @override
  SyncSchema<Pack> getSchema() {
    return schema;
  }

  @override
  Map<String, dynamic> toJson() {
    final values = super.toJson();
    final packEntries = this.entries;
    if (packEntries != null) {
      values["_pack_entries"] = packEntries.map((e) => e.toJson()).toList();
    }

    return values;
  }
}
