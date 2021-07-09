/*

@SyncCollection(name  = @Name(local = "location_products", remote = "productlocation"))
public class LocationProduct extends BaseRemoteModel {

    public interface Field{
        SqlLiveQueryColumn UNIT_COUNT = new SqlLiveQueryColumn(LocationProduct$Schema.Column.UNIT_COUNT);
    }

    @SyncColumn(referenceOf = Location.class, flags = SyncDbFlag.AccessMode.REMOTE_READ, name = @Name(remote = "location_id") )
    public ObjectRowId locationUid;

    @SyncColumn(name = @Name(remote = "unitcount", local = "unit_count"))
    public int unitCount;

}

 */

import 'package:vgbnd/sync/sync_object.dart';
import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/sync/schema.dart';

import 'location.dart';

class ProductLocation extends SyncObject<ProductLocation> {
  static const SchemaName SCHEMA_NAME = 'productlocation';

  int? productId;
  int? locationId;

  static final schema = SyncDbSchema<ProductLocation>(SCHEMA_NAME,
      allocate: () => ProductLocation(),
      columns: [
        SyncDbColumn.readonly("product_id", referenceOf: Product.SCHEMA_NAME),
        SyncDbColumn.readonly("location_id", referenceOf: Location.SCHEMA_NAME),
        SyncDbColumn.readonly("unitcount"),
      ]);

  @override
  SyncDbSchema<ProductLocation> getSchema() {
    return schema;
  }
}
