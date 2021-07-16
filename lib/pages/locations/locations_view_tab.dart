
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/pages/locations/coil_form.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';

import 'locations_common.dart';

class LocationViewTab extends StatelessWidget {
  final int _locationId;

  LocationViewTab(this._locationId);

  @override
  Widget build(BuildContext context) {
    final controller = LocationObjectListController();
    controller.setGroupByColumn("tray_id");

    return Stack(
      children: [
        buildTable(context, controller),
        Positioned(
          child: MyFab(
            menuItems: [
              MyFabMenuItem(text: "Location Info", icon: Icons.info_outline_rounded, onTap: () {
                print("Location Info");
              }),
              MyFabMenuItem(text: "Add Coil", icon: Icons.add_circle_outline, onTap: () {
                print("add coil");
                Get.to(() => CoilForm());

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
      dataSource: LocationCoilStockDatasource(_locationId),
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
}

class MyFab extends StatelessWidget {
  List<MyFabMenuItem>? menuItems;
  IconData? fabIcon;
  VoidCallback? onTap;
  late bool enabled;
  late bool loading;

  MyFab({this.menuItems, this.fabIcon, this.onTap, bool? enabled, bool? loading}) {
    this.enabled = enabled ?? true;
    this.loading = loading ?? false;
    if (this.loading) {
      this.enabled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final menuItems = this.menuItems ?? [];

    final fabIcon = this.fabIcon ?? (menuItems.isNotEmpty ? Icons.menu : null);

    final List<Widget> children = [];

    if (this.loading) {
      children.add(SizedBox(
        child: CircularProgressIndicator(
          strokeWidth: 6,
          color: theme.primaryColorDark,
        ),
        height: 60,
        width: 60,
      ));
    }

    children.add(FloatingActionButton(
      child: Icon(fabIcon),
      onPressed: this.enabled
          ? onTap ??
              () {
                print("no handler");
              }
          : null,
    ));

    if (this.enabled && !this.loading && menuItems.isNotEmpty) {
      children.add(PopupMenuButton<int>(
        onSelected: (value) {
          menuItems[value].onTap();
        },
        child: Container(
          height: 60,
          width: 60,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(60),
          ),
          //child: Icon(Icons.menu, color: Colors.white), <-- You can give your icon here
        ),
        itemBuilder: (context) {
          return menuItems.map((final item) {
            final idx = menuItems.indexOf(item);
            return PopupMenuItem(
              value: idx,
              child: Row(
                children: <Widget>[
                  Icon(item.icon, size: 24, color: theme.primaryColor,),
                  SizedBox(
                    width: 16,
                  ),
                  Text(item.text, style: TextStyle(color: theme.primaryColor),),
                ],
              ),
            );
          }).toList();
        },
      ));
    }

    return Stack(children: children);
  }
}

class MyFabMenuItem {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  MyFabMenuItem({required this.text, required this.icon, required this.onTap});
}
