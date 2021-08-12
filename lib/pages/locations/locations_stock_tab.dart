
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vgbnd/models/restock.dart';
import 'package:vgbnd/models/restock_entry.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/app_fab.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';

import 'locations_common.dart';

class LocationsStockTab extends StatefulWidget {
  final LocationStockObjectListController controller;

  LocationsStockTab(this.controller, {Key? key}) : super(key: key);

  @override
  _LocationsStockTabState createState() {
    return _LocationsStockTabState();
  }
}

class _LocationsStockTabState extends State<LocationsStockTab> with AutomaticKeepAliveClientMixin<LocationsStockTab> {
  var _isFabLoading = false;
  var _isInitialized = false;

  @override
  void initState() {
    super.initState();
    this.widget.controller.prepare(() {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        buildTable(context, widget.controller),
        Positioned(
          child: AppFab(
            loading: _isFabLoading,
            menuItems: [
              AppFabMenuItem(
                  text: "Clear",
                  icon: Icons.clear,
                  onTap: () {
                    widget.controller.clearValues();
                    print("Location Info");
                  }),
              AppFabMenuItem(
                  text: "Reset",
                  icon: Icons.undo,
                  onTap: () {
                    widget.controller.resetValues();
                  }),
              AppFabMenuItem(
                  text: "Par values",
                  icon: Icons.clear_all,
                  onTap: () {
                    widget.controller.fillWithParValues();
                  }),
              AppFabMenuItem(
                  text: "Submit",
                  icon: Icons.done_all,
                  onTap: () {
                    widget.controller.submitRestock();
                  }),
            ],
          ),
          bottom: 16,
          right: 16,
        )
      ],
    );
  }

  Widget buildTable(BuildContext context, LocationStockObjectListController controller) {
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
          buildHeaderCellFunc: buildToggleCasesUnitsHeaderFunc,
          buildBodyCellFunc: (context, col, ctrl, renderIndex) {
            int caseSize = controller.getDatasourceValueAt<int>("product_case_size", renderIndex: renderIndex) ?? 1;
            int? packUnitCount = controller.getDefaultUnitCount(renderIndex: renderIndex);
            if (caseSize < 1) {
              caseSize = 1;
            }

            return controller.buildCaseUnitStepperInput(
                namespace: "stock",
                objId: controller.getObjectId(renderIndex: renderIndex),
                caseSize: caseSize,
                initialUnitCount: packUnitCount,
                minValue: 0);
          },
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => !widget.controller.isDisposed;
}

class LocationStockObjectListController extends LocationObjectListController {
  LocationStockObjectListController(int locationId)
      : super(locationId, LocationCoilStockDatasource(locationId, prodRequired: true, activeCoilsOnly: true)) {
    setGroupByColumn("tray_id");

    _init();
  }

  _init() async {}

  prepare(VoidCallback callback) async {
    callback();
  }

  fillWithParValues() {
    for (var dsIndex = 0; dsIndex < datasourceCount; dsIndex += 1) {
      final parValue = this.getDatasourceValueAt<int>("par_value", datasourceIndex: dsIndex) ?? 1;
      this.setUnitCount(this.getObjectId(datasourceIndex: dsIndex), parValue);
    }
    this.invalidateData();
  }

  int? getDefaultUnitCount({int? renderIndex, int? datasourceIndex}) {
    final packUnitsCount =
        getDatasourceValueAt<int>("pack_units_count", datasourceIndex: datasourceIndex, renderIndex: renderIndex);
    if (packUnitsCount == null || packUnitsCount <= 0) {
      return null;
    }
    int? currentFill =
        getDatasourceValueAt<int>("current_fill", datasourceIndex: datasourceIndex, renderIndex: renderIndex);
    if ((currentFill ?? 0) < 0) {
      currentFill = 0;
    }
    return (currentFill ?? 0) + packUnitsCount;
  }

  submitRestock() async {
    final List<RestockEntry> restockEntries = [];
    for (var dsIndex = 0; dsIndex < datasourceCount; dsIndex += 1) {
      final coilId = getObjectId(datasourceIndex: dsIndex);
      //final unitCount = hasUnitCount(coilId) ? getUnitCount(coilId) : getDefaultUnitCount(datasourceIndex: dsIndex);
      int? unitCount;
      if (hasUnitCount(coilId)) {
        // 0 is valid as long as it's set by the user
        unitCount = getUnitCount(coilId) ?? 0;
        if ((unitCount) < 0) {
          unitCount = null;
        }
      } else {
        final defUnitCount = getDefaultUnitCount(datasourceIndex: dsIndex) ?? 0;
        // defUnitCount must be always != null && >0 in order to be considered valid
        if (defUnitCount > 0) {
          unitCount = defUnitCount;
        }
      }
      final productId = getDatasourceValueAt<int>("product_id", datasourceIndex: dsIndex) ?? 0;
      if (unitCount == null) {
        continue;
      }
      final e = RestockEntry();
      e.unitCount = unitCount;
      e.coilId = coilId;
      e.locationId = locationId;
      e.productId = productId;
      restockEntries.add(e);
    }

    if (restockEntries.isEmpty) {
      Fluttertoast.showToast(msg: "No values to save");
      return;
    }

    final restock = Restock();
    restock.locationId = locationId;
    restock.entries = restockEntries;

    final res = await SyncController.current().upsertObject(restock);
    print(res);

    if (res.isSuccessful) {
      //await SyncEngine.current().pullChanges();

      Fluttertoast.showToast(msg: "Restock created successfully.");
    } else {
      Fluttertoast.showToast(msg: res.primaryErrorMessage("Restock save error"));
    }
    this.resetValues();
  }
}
