import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/mutation/pack_mutation_handler.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

import 'pack_entry.dart';

final _packMutationHandler = PackMutationHandler();

class Pack extends SyncObject<Pack> {
  static const SchemaName SCHEMA_NAME = 'packs';
  static const String _PACK_ENTRIES_ATTR = "__pack_entries";

  int? locationId;
  int? restockId;

  List<PackEntry>? entries;

  static Pack? fromJson(Map<String, dynamic> values) {
    return SyncObject.fromJson<Pack>(values);
  }

  static final schema = SyncSchema<Pack>(SCHEMA_NAME,
      syncOps: [SyncSchemaOp.RemoteWrite],
      localMutationHandler: _packMutationHandler,
      remoteMutationHandler: _packMutationHandler,
      allocate: () => Pack(),
      columns: [
        SyncColumn.id(),
        SyncColumn(
          "location_id",
          referenceOf: ReferenceOfSchema(Location.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete),
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
    values[_PACK_ENTRIES_ATTR] = List.from(this.entries?.map((e) => e.toJson()) ?? []);
    return values;
  }

  @override
  assignValues(Map<String, dynamic>? values) {
    super.assignValues(values);
    if (values == null) {
      return;
    }
    if (values[_PACK_ENTRIES_ATTR] is List) {
      this.entries = (values[_PACK_ENTRIES_ATTR] as List).map((e) => PackEntry.schema.instantiate(e as Map<String, dynamic>)).toList();
    }
  }
}
