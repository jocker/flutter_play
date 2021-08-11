import 'package:vgbnd/models/restock_entry.dart';
import 'package:vgbnd/sync/mutation/restock_mutation_handler.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

import 'location.dart';

final _restockMutationHandler = RestockMutationHandler();

class Restock extends SyncObject<Restock> {
  static const SchemaName SCHEMA_NAME = 'restocks';

  static const String _RESTOCK_ENTRIES_ATTR = "__restock_entries";

  static final schema = SyncSchema<Restock>(SCHEMA_NAME,
      remoteMutationHandler: _restockMutationHandler,
      localMutationHandler: _restockMutationHandler,
      allocate: () => Restock(),
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
      ]);

  static Restock? fromJson(Map<String, dynamic>? values) {
    if (values == null) {
      return null;
    }
    return SyncObject.fromJson<Restock>(values);
  }

  @override
  SyncSchema<Restock> getSchema() {
    return Restock.schema;
  }

  int? locationId;

  List<RestockEntry>? entries;

  @override
  Map<String, dynamic> toJson() {
    final values = super.toJson();
    values[_RESTOCK_ENTRIES_ATTR] = List.from(this.entries?.map((e) => e.toJson()) ?? []);
    return values;
  }

  @override
  assignValues(Map<String, dynamic>? values) {
    super.assignValues(values);
    if (values == null) {
      return;
    }
    if (values[_RESTOCK_ENTRIES_ATTR] is List) {
      this.entries = (values[_RESTOCK_ENTRIES_ATTR] as List)
          .map((e) => RestockEntry.schema.instantiate(e as Map<String, dynamic>))
          .toList();
    }
  }
}
