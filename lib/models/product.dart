import 'package:vgbnd/sync/schema.dart';

import '../sync/sync_object.dart';

class Product extends SyncObject<Product> {
  static const SchemaName SCHEMA_NAME = 'products';

  static final schema = SyncSchema<Product>(SCHEMA_NAME, allocate: () => Product(), columns: [
    SyncColumn.id(),
    SyncColumn<Product>(
      "name",
      readAttribute: (dest) => dest.name,
      assignAttribute: (value, key, dest) {
        dest.name = value.getValue(key) ?? dest.name;
      },
    ),
    SyncColumn<Product>(
      "costbasis",
      readAttribute: (dest) => dest.costBasis,
      assignAttribute: (value, key, dest) {
        dest.costBasis = value.getValue(key) ?? dest.costBasis;
      },
    ),
    SyncColumn<Product>(
      "pricepercase",
      readAttribute: (dest) => dest.pricePerCase,
      assignAttribute: (value, key, dest) {
        dest.pricePerCase = value.getValue(key) ?? dest.pricePerCase;
      },
    ),
    SyncColumn<Product>(
      "casesize",
      readAttribute: (dest) => dest.caseSize,
      assignAttribute: (value, key, dest) {
        dest.caseSize = value.getValue(key) ?? dest.caseSize;
      },
    ),
    SyncColumn<Product>(
      "source_category_name",
      readAttribute: (dest) => dest.sourceCategoryName,
      assignAttribute: (value, key, dest) {
        dest.sourceCategoryName = value.getValue(key) ?? dest.sourceCategoryName;
      },
    ),
    SyncColumn<Product>(
      "category_name",
      readAttribute: (dest) => dest.categoryName,
      assignAttribute: (value, key, dest) {
        dest.categoryName = value.getValue(key) ?? dest.categoryName;
      },
    ),
    SyncColumn<Product>(
      "roc",
      readAttribute: (dest) => dest.roc,
      assignAttribute: (value, key, dest) {
        dest.roc = value.getValue(key) ?? dest.roc;
      },
    ),
    SyncColumn<Product>(
      "inventory_unit_count",
      readAttribute: (dest) => dest.inventoryUnitCount,
      assignAttribute: (value, key, dest) {
        dest.inventoryUnitCount = value.getValue(key) ?? dest.inventoryUnitCount;
      },
    ),
    SyncColumn<Product>(
      "required_unit_count",
      readAttribute: (dest) => dest.requiredUnitCount,
      assignAttribute: (value, key, dest) {
        dest.requiredUnitCount = value.getValue(key) ?? dest.requiredUnitCount;
      },
    ),
    SyncColumn<Product>(
      "archived",
      readAttribute: (dest) => dest.archived,
      assignAttribute: (value, key, dest) {
        dest.archived = value.getValue(key) ?? dest.archived;
      },
    ),
    SyncColumn<Product>(
      "wh_order",
      readAttribute: (dest) => dest.whOrder,
      assignAttribute: (value, key, dest) {
        dest.whOrder = value.getValue(key) ?? dest.whOrder;
      },
    ),
  ]);

  String? name;
  double? costBasis;
  double? pricePerCase;
  int? caseSize;
  String? sourceCategoryName;
  String? categoryName;
  double? roc;
  int? inventoryUnitCount;
  int? requiredUnitCount;
  bool? archived;
  int? whOrder;

  @override
  SyncSchema<Product> getSchema() {
    return schema;
  }
}
