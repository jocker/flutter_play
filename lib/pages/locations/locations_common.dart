import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:vgbnd/helpers/sql_select_query.dart';
import 'package:vgbnd/widgets/case_unit_stepper_input.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';
import 'package:vgbnd/widgets/table_view/table_view_controller.dart';
import 'package:vgbnd/widgets/table_view/table_view_data_source.dart';

class LocationCoilStockDatasource extends SqlQueryDataSource {
  final int locationId;

  LocationCoilStockDatasource(this.locationId, bool prodRequired)
      : super(SqlSelectQuery.from("columns")
          ..field("columns.display_name", "display_name")
          ..field("columns.tray_id", "tray_id")
          ..field("ifnull(products.name, 'Not Assigned')", "product_name")
          ..field("columns.id", "coil_id")
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
          ..where("columns.location_id=?", [locationId]));
}

class LocationObjectListController extends TableViewController {
  LocationObjectListController(SqlQueryDataSource ds) : super(ds, addFabSpacer: true);

  var _showCases = false;
  final _coilValues = new HashMap<int, int?>();

  bool get showCases {
    return _showCases;
  }

  setShowCases(bool value) {
    if (_showCases != value) {
      _showCases = value;
      notifyListeners();
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

  bool hasUnitCount(int id) {
    return _coilValues.containsKey(id);
  }

  int getObjectId(int renderIndex) {
    return getDatasourceValueAt<int>("coil_id", renderIndex: renderIndex)!;
  }

  Widget buildCaseUnitStepperInput(int objId, int caseSize, int initialUnitCount) {
    return CaseUnitStepperInput(
      objId,
      caseSize: caseSize,
      unitCount: getUnitCount(objId, initialUnitCount),
      initialUnitCount: initialUnitCount,
      showCases: this.showCases,
      key: ValueKey("CaseUnitStepperInput-${this.showCases}-$objId"),
      onChanged: (value) {
        setUnitCount(objId, value);
      },
    );
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
