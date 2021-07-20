import 'package:flutter/material.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';

import 'locations_common.dart';

class LocationsPackTab extends StatelessWidget{
  final int _locationId;
  final LocationObjectListController controller ;
  LocationsPackTab(this._locationId, this.controller);

  @override
  Widget build(BuildContext context) {
    return buildTable(context, controller);
  }

  Widget buildTable(BuildContext context, LocationObjectListController controller) {
    return TableView(
      controller: controller,
      onRowClick: (controller, renderIndex) {},
      buildBodyRowFunc: buildTrayIdHeaderFunc,
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
          label: 'Stock',
          width: 140,
          contentAlignment: Alignment.centerRight,
          buildBodyCellFunc: (context, col, ctrl, renderIndex) {

            int? lastFill = controller.getDatasourceValueAt("current_fill", renderIndex: renderIndex) ?? 0;
            int caseSize = controller.getDatasourceValueAt<int>("product_case_size", renderIndex: renderIndex) ?? 1;
            final parValue = controller.getDatasourceValueAt<int>("par_value", renderIndex: renderIndex) ?? 0;

            if (caseSize < 1) {
              caseSize = 1;
            }

            return controller.buildCaseUnitStepperInput(controller.getObjectId(renderIndex), caseSize, lastFill);

          },
        ),
      ],
    );
  }

}