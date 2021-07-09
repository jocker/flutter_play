import 'package:vgbnd/sync/schema.dart';

import '../sync/sync_object.dart';

class Product extends SyncObject<Product> {
  static const SchemaName SCHEMA_NAME = 'products';

  static final schema = SyncDbSchema<Product>(SCHEMA_NAME, allocate: () => Product(), columns: [
    SyncDbColumn.id(),
    SyncDbColumn<Product>(
      "name",
      readAttribute: (dest) => dest.name,
      assignAttribute: (value, key, dest) {
        dest.name = value.getValue(key) ?? dest.name;
      },
    ),
    SyncDbColumn<Product>(
      "costbasis",
      readAttribute: (dest) => dest.costBasis,
      assignAttribute: (value, key, dest) {
        dest.costBasis = value.getValue(key) ?? dest.costBasis;
      },
    ),
    SyncDbColumn<Product>(
      "pricepercase",
      readAttribute: (dest) => dest.pricePerCase,
      assignAttribute: (value, key, dest) {
        dest.pricePerCase = value.getValue(key) ?? dest.pricePerCase;
      },
    ),
    SyncDbColumn<Product>(
      "casesize",
      readAttribute: (dest) => dest.caseSize,
      assignAttribute: (value, key, dest) {
        dest.caseSize = value.getValue(key) ?? dest.caseSize;
      },
    ),
    SyncDbColumn<Product>(
      "source_category_name",
      readAttribute: (dest) => dest.sourceCategoryName,
      assignAttribute: (value, key, dest) {
        dest.sourceCategoryName = value.getValue(key) ?? dest.sourceCategoryName;
      },
    ),
    SyncDbColumn<Product>(
      "category_name",
      readAttribute: (dest) => dest.categoryName,
      assignAttribute: (value, key, dest) {
        dest.categoryName = value.getValue(key) ?? dest.categoryName;
      },
    ),
    SyncDbColumn<Product>(
      "roc",
      readAttribute: (dest) => dest.roc,
      assignAttribute: (value, key, dest) {
        dest.roc = value.getValue(key) ?? dest.roc;
      },
    ),
    SyncDbColumn<Product>(
      "inventory_unit_count",
      readAttribute: (dest) => dest.inventoryUnitCount,
      assignAttribute: (value, key, dest) {
        dest.inventoryUnitCount = value.getValue(key) ?? dest.inventoryUnitCount;
      },
    ),
    SyncDbColumn<Product>(
      "required_unit_count",
      readAttribute: (dest) => dest.requiredUnitCount,
      assignAttribute: (value, key, dest) {
        dest.requiredUnitCount = value.getValue(key) ?? dest.requiredUnitCount;
      },
    ),
    SyncDbColumn<Product>(
      "archived",
      readAttribute: (dest) => dest.archived,
      assignAttribute: (value, key, dest) {
        dest.archived = value.getValue(key) ?? dest.archived;
      },
    ),
    SyncDbColumn<Product>(
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
  SyncDbSchema<Product> getSchema() {
    return schema;
  }
}
