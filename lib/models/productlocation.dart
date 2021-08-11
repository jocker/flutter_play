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

import 'package:vgbnd/models/product.dart';
import 'package:vgbnd/sync/schema.dart';
import 'package:vgbnd/sync/sync_object.dart';

import 'location.dart';

class ProductLocation extends SyncObject<ProductLocation> {
  static const SchemaName SCHEMA_NAME = 'productlocation';

  int? productId;
  int? locationId;
  int? unitCount;

  static final schema = SyncSchema<ProductLocation>(SCHEMA_NAME, allocate: () => ProductLocation(), columns: [
    SyncColumn("product_id", readAttribute: (dest) {
      return dest.productId;
    }, assignAttribute: (value, key, dest) {
      dest.productId = value.getValue(key);
    }, referenceOf: ReferenceOfSchema(Product.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete)),
    SyncColumn("location_id", readAttribute: (dest) {
      return dest.locationId;
    }, assignAttribute: (value, key, dest) {
      dest.locationId = value.getValue(key);
    }, referenceOf: ReferenceOfSchema(Location.SCHEMA_NAME, onDeleteReferenceDo: OnDeleteReferenceDo.Delete)),
    SyncColumn(
      "unitcount",
      readAttribute: (dest) {
        return dest.unitCount;
      },
      assignAttribute: (value, key, dest) {
        dest.unitCount = value.getValue(key);
      },
    ),
  ]);

  @override
  SyncSchema<ProductLocation> getSchema() {
    return schema;
  }
}
