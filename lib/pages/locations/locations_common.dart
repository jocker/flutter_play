import 'dart:async';
import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vgbnd/helpers/sql_select_query.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/pack_entry.dart';
import 'package:vgbnd/models/restock.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/case_unit_stepper_input.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';
import 'package:vgbnd/widgets/table_view/table_view_controller.dart';
import 'package:vgbnd/widgets/table_view/table_view_data_source.dart';

class LocationCoilStockDatasource extends SqlQueryDataSource {
  final int locationId;

  LocationCoilStockDatasource(this.locationId, {required bool prodRequired, required bool activeCoilsOnly})
      : super(SqlSelectQuery.from("columns")
          ..field("columns.display_name", "display_name")
          ..field("columns.tray_id", "tray_id")
          ..field("ifnull(products.name, 'Not Assigned')", "product_name")
          ..field("columns.id", "coil_id")
          ..field("columns.id", "object_id")
          ..field("products.id", "product_id")
          ..field("ifnull(columns.last_fill, 0)", "last_fill")
          ..field("ifnull(columns.capacity, 0)", "par_value")
          ..field("ifnull(column_product_inventory.pack_units_count, 0)", "pack_units_count")
          ..field("ifnull(column_product_inventory.sold_units_count, 0)", "sold_units_count")
          ..field("ifnull(column_product_inventory.current_fill, 0)", "current_fill")
          ..field("products.casesize", "product_case_size")
          ..join("join column_product_inventory on columns.id = column_product_inventory.column_id")
          ..join("left join products on columns.product_id=products.id")
          ..order("tray_id asc, columns.display_name asc")
          ..where(prodRequired ? "products.id is not null" : "true")
          ..where(activeCoilsOnly ? "columns.active = 1" : "true")
          //..where("columns.id=2106831")
          ..where("columns.location_id=?", [locationId])) {}
}

class LocationCoilStockWhOrderDatasource extends SqlQueryDataSource {
  LocationCoilStockWhOrderDatasource(int locationId)
      : super(SqlSelectQuery.from("location_product_inventory")
          ..join("join products on products.id=location_product_inventory.product_id")
          ..field("products.id", "product_id")
          ..field("products.id", "object_id")
          ..field("products.wh_order", "wh_order")
          ..field("ifnull(products.name, 'Not Assigned')", "product_name")
          ..field("location_product_inventory.coil_ids", "coil_ids")
          ..field("ifnull(location_product_inventory.last_fill, 0)", "last_fill")
          ..field("ifnull(location_product_inventory.par_value, 0)", "par_value")
          ..field("ifnull(location_product_inventory.pack_units_count, 0)", "pack_units_count")
          ..field("ifnull(location_product_inventory.sold_units_count, 0)", "sold_units_count")
          ..field("products.casesize", "casesize")
          ..field("ifnull(location_product_inventory.current_fill, 0)", "current_fill")
          ..where("products.id is not null")

          //..where("products.id=238921")
          ..where("location_product_inventory.location_id=?", [locationId])
          ..order(
              "case when products.wh_order = 0 then null else products.wh_order end asc, ifnull(products.name, 'Not Assigned') asc"));
}

class LocationObjectListController extends TableViewController {
  final List<StreamSubscription> _subscriptions = [];
  int _instanceId = 1;
  final int locationId;
  var _isDisposed = false;

  LocationObjectListController(this.locationId, SqlQueryDataSource ds) : super(ds, addFabSpacer: true) {
    _setup();
  }

  _setup() async {
    final onChanged = await SyncEngine.current()
        .createSchemaChangedStream([Coil.SCHEMA_NAME, Pack.SCHEMA_NAME, PackEntry.SCHEMA_NAME, Restock.SCHEMA_NAME]);
    final sub = onChanged.listen((event) {
      if (_isDisposed) {
        return;
      }
      dataSource.reload();
    });

    this.registerSubscription(sub);
  }

  registerSubscription(StreamSubscription sub) {
    if (_isDisposed) {
      sub.cancel();
    } else {
      _subscriptions.add(sub);
    }
  }

  var _showCases = false;
  final _coilValues = new HashMap<int, int?>();

  bool get showCases {
    return _showCases;
  }

  setShowCases(bool value) {
    if (_showCases != value) {
      _showCases = value;
      invalidateData();
    }
  }

  setUnitCount(int id, int? coilValue) {
    _coilValues[id] = coilValue;
  }

  int? getUnitCount(int id, [int? defaultValue]) {
    if (hasUnitCount(id)) {
      return _coilValues[id];
    }
    return defaultValue;
  }

  clearValues() {
    for (var i = 0; i < dataSource.itemCount; i++) {
      setUnitCount(getObjectId(datasourceIndex: i), null);
    }
    invalidateData();
  }

  resetValues() {
    if (_coilValues.isNotEmpty) {
      _coilValues.clear();
      invalidateData();
    }
  }

  invalidateData() {
    _instanceId += 1;
    notifyListeners();
  }

  bool hasUnitCount(int id) {
    return _coilValues.containsKey(id);
  }

  int getObjectId({int? renderIndex, int? datasourceIndex}) {
    return getDatasourceValueAt<int>("object_id", renderIndex: renderIndex, datasourceIndex: datasourceIndex)!;
  }

  Widget buildCaseUnitStepperInput(
      {required int objId,
      required int caseSize,
      required int? initialUnitCount,
      required String namespace,
      int? minValue}) {
    final unitCount = getUnitCount(objId, initialUnitCount);
    return CaseUnitStepperInput(
      objId,
      caseSize: caseSize,
      unitCount: unitCount,
      initialUnitCount: initialUnitCount,
      showCases: this.showCases,
      key: ValueKey("CaseUnitStepperInput-$namespace-$_instanceId-$objId-$unitCount-$initialUnitCount"),
      minValue: minValue,
      onChanged: (value) {
        setUnitCount(objId, value);
      },
    );
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    super.dispose();
    dataSource.dispose();
    _subscriptions.forEach((element) {
      element.cancel();
    });
    _subscriptions.clear();
  }

  bool get isDisposed {
    return _isDisposed;
  }
}

BuildHeaderCellFunc buildToggleCasesUnitsHeaderFunc = (context, col, ctrl) {
  final controller = ctrl as LocationObjectListController;

  final textStyleActive = col.getDefaultTextStyleForHeader(context, controller);
  final textStyleInactive = textStyleActive.copyWith(color: textStyleActive.color!.withOpacity(0.5));
  final w = Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      InkWell(
        child: Text(
          "Units",
          style: !controller.showCases ? textStyleActive : textStyleInactive,
        ),
        onTap: () {
          controller.setShowCases(false);
        },
      ),
      Text(" / "),
      InkWell(
        child: Text(
          "Cases",
          style: controller.showCases ? textStyleActive : textStyleInactive,
        ),
        onTap: () {
          controller.setShowCases(true);
        },
      )
    ],
  );

  return w;
};

BuildBodyRowFunc buildTrayIdHeaderFunc = (context, c, viewType, renderIndex) {
  final controller = c as LocationObjectListController;

  switch (viewType) {
    case TableViewController.ITEM_VIEW_TYPE_GROUP_HEADER:
      final dsIndex = controller.getDatasourceIndex(renderIndex);
      final trayId = controller.getDatasourceValueAt("tray_id", datasourceIndex: dsIndex);

      final theme = Theme.of(context);

      return Container(
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
          color: theme.primaryColor,
          width: 1,
        ))),
        height: 54,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 8),
        child: Text(
          "Tray $trayId",
          style: TextStyle(color: theme.primaryColorDark, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      );

    default:
      return null;
  }
};
