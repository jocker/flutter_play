import 'package:flutter/material.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/pages/locations/coil_form.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/app_fab.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';

import 'locations_common.dart';

class LocationViewTab extends StatelessWidget {
  final LocationObjectListController controller;

  LocationViewTab(this.controller);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        buildTable(context, controller),
        Positioned(
          child: AppFab(
            menuItems: [
              AppFabMenuItem(
                  text: "Location Info",
                  icon: Icons.info_outline_rounded,
                  onTap: () {
                    print("Location Info");
                  }),
              AppFabMenuItem(
                  text: "Add Coil",
                  icon: Icons.add_circle_outline,
                  onTap: (){
                    final c = Coil();
                    c.locationId = controller.locationId;
                    _editCoil(c);
                  })
            ],
          ),
          bottom: 16,
          right: 16,
        )
      ],
    );
  }

  Widget buildTable(BuildContext context, LocationObjectListController controller) {
    return TableView(
      controller: controller,
      onRowClick: (controller, renderIndex) async {
        final coilId = controller.getDatasourceValueAt<int>("coil_id", renderIndex: renderIndex);
        if (coilId == null) {
          return;
        }
        final coil = await SyncController.current().loadObject(Coil.schema, id: coilId);
        if (coil != null) {
          _editCoil(coil);
        }

      },
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
          buildBodyCellFunc: (context, col, ctrl, index) {
            int? lastFill = controller.getDatasourceValueAt("current_fill", renderIndex: index) ?? 0;
            int caseSize = controller.getDatasourceValueAt<int>("product_case_size", renderIndex: index) ?? 1;
            final parValue = controller.getDatasourceValueAt<int>("par_value", renderIndex: index) ?? 0;

            if (caseSize < 1) {
              caseSize = 1;
            }

            final theme = Theme.of(context);
            return Text("${lastFill.toString().padLeft(2, '0')} / ${parValue.toString().padLeft(2, '0')}",
                style: TextStyle(color: lastFill >= parValue ? theme.primaryColor : Colors.red));
          },
        ),
      ],
    );
  }

  _editCoil(Coil coil) async{
    final res = await CoilForm.edit(coil);
  }
}
