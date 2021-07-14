import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:vgbnd/data/cursor.dart';
import 'package:vgbnd/helpers/sql_select_query.dart';
import 'package:vgbnd/widgets/case_unit_stepper_input.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';

class XController extends TableViewController {
  var _showCases = false;

  bool get showCases {
    return _showCases;
  }

  setShowCases(bool value) {
    if (_showCases != value) {
      _showCases = value;
      notifyListeners();
    }
  }
}

class DataSource extends TableViewDataSource {
  final int locationId;
  late SqlSelectQueryBuilder _query;

  DataSource(this.locationId) {
    _query = SqlSelectQuery.from("columns")
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
      ..order("tray_id asc")
      ..where("columns.location_id=?", [locationId]);
  }

  @override
  Future<Cursor> initCursor() {
    final q = _query.build();
    return _query.build().run();
  }
}

class LocationViewTab extends StatelessWidget {
  final _values = HashMap<int, int?>();

  @override
  Widget build(BuildContext context) {
    final controller = XController();
    controller.setGroupByColumn("tray_id");
    return buildTable(context, controller);
  }

  Widget buildTable(BuildContext context, XController controller) {
    return TableView(
      dataSource: DataSource(226013),
      controller: controller,
      buildBodyRowFunc: (context, _, viewType, renderIndex) {
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
      },
      columns: [
        TableColumn(
          'display_name',
          label: "Coil",
          sortable: false,
          width: 60,
        ),
        TableColumn(
          'product_name',
          label: "Product",
          sortable: false,
        ),
        TableColumn(
          'unit_count',
          width: 140,
          contentAlignment: Alignment.centerRight,
          buildBodyCellFunc: (context, col, ctrl, index) {
            int? unitCount = null;

            int? lastFill = controller.getDatasourceValueAt("current_fill", renderIndex: index) ?? 0;
            int caseSize = controller.getDatasourceValueAt<int>("product_case_size", renderIndex: index) ?? 1;
            final coilId = controller.getDatasourceValueAt<int>("coil_id", renderIndex: index)!;
            final parValue = controller.getDatasourceValueAt<int>("par_value", renderIndex: index) ?? 0;

            if(caseSize < 1){
              caseSize = 1;
            }



            final theme = Theme.of(context);
            return Text("${lastFill.toString().padLeft(2, '0')} / ${parValue.toString().padLeft(2, '0')}",
                style: TextStyle(color: lastFill >= parValue ? theme.primaryColor : Colors.red));

            return Text("${1.toString().padLeft(2, '0')} / ${1.toString().padLeft(2, '0')}",
                textAlign: TextAlign.right);

            if (_values.containsKey(index)) {
              unitCount = _values[index];
            } else {
              unitCount = lastFill;
            }

            return CaseUnitStepperInput(
              coilId,
              caseSize: caseSize,
              unitCount: unitCount,
              initialUnitCount: lastFill,
              showCases: controller.showCases,
              key: ValueKey("CaseUnitStepperInput-${controller.showCases}-$index-$unitCount}"),
              onChanged: (value) {
                _values[index] = value;
              },
            );
          },
          buildHeaderCellFunc: (context, col, ctrl) {
            final textStyleActive = col.getDefaultTextStyleForHeader(context, controller);
            final textStyleInactive = textStyleActive.copyWith(color: textStyleActive.color!.withOpacity(0.5));
            final w =  Row(
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

          },
        ),
      ],
    );
  }
}
