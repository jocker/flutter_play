import 'dart:async';
import 'dart:collection';
import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vgbnd/constants/constants.dart';
import 'package:vgbnd/ext.dart';
import 'package:vgbnd/models/coil.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/models/pack.dart';
import 'package:vgbnd/models/pack_entry.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/app_fab.dart';
import 'package:vgbnd/widgets/table_view/table_view.dart';

import 'locations_common.dart';

class LocationsPackTab extends StatefulWidget {
  final LocationPackObjectListController controller;

  LocationsPackTab(this.controller);

  @override
  _LocationsPackTabState createState() => _LocationsPackTabState();
}

class _LocationsPackTabState extends State<LocationsPackTab> with AutomaticKeepAliveClientMixin<LocationsPackTab> {
  var _isFabLoading = false;
  var _isInitialized = false;

  @override
  void initState() {
    super.initState();
    this.widget.controller.init(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitialized = true;
      });
    });
  }

  init() async {}

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
                  text: "Submit",
                  icon: Icons.done_all,
                  onTap: () {
                    widget.controller.createPack(this);
                  }),
            ],
          ),
          bottom: 16,
          right: 16,
        )
      ],
    );
  }

  Widget buildTable(BuildContext context, LocationPackObjectListController controller) {
    late final TableColumn primaryColumn;
    if (this.widget.controller.useWarehouseOrder) {
      primaryColumn = TableColumn(
        'wh_order',
        label: "Sort",
        sortable: false,
        width: 60,
        buildBodyCellFunc: (context, col, controller, index) {
          int? whOrder = controller.getDatasourceValueAt("wh_order");
          return Text(whOrder != null ? whOrder.toString() : "-");
        },
      );
    } else {
      primaryColumn = TableColumn(
        'display_name',
        label: "Coil",
        sortable: false,
        width: 60,
      );
    }

    return TableView(
      controller: controller,
      onRowClick: (controller, renderIndex) {},
      buildBodyRowFunc: buildTrayIdHeaderFunc,
      columns: [
        primaryColumn,
        TableColumn(
          'product_name',
          label: "Product",
          sortable: false,
        ),
        TableColumn('unit_count',
            label: 'Stock',
            width: 140,
            contentAlignment: Alignment.centerRight,
            buildHeaderCellFunc: buildToggleCasesUnitsHeaderFunc, buildBodyCellFunc: (context, col, ctrl, renderIndex) {
          int caseSize = controller.getDatasourceValueAt<int>("product_case_size", renderIndex: renderIndex) ?? 1;
          final coilIds = controller.getDatasourceValueAt<String>("coil_ids", renderIndex: renderIndex) ?? 1;
          int? unitCount = controller.getPackUnitCount(renderIndex: renderIndex);
          final id = controller.getObjectId(renderIndex: renderIndex);
          if (caseSize < 1) {
            caseSize = 1;
          }
          return controller.buildCaseUnitStepperInput(
              namespace: "pack",
              objId: controller.getObjectId(renderIndex: renderIndex),
              caseSize: caseSize,
              initialUnitCount: unitCount);
        }),
      ],
    );
  }

  setShowFabLoading(bool value) {
    if (value != _isFabLoading) {
      setState(() {
        _isFabLoading = value;
      });
    }
  }

  @override
  bool get wantKeepAlive => true;
}

class LocationPackObjectListController extends LocationObjectListController {
  static const VIEW_TYPE_PACK_HEADER = 10;

  final bool useWarehouseOrder;

  var _isInitialized = false;
  var _hasUnsubmittedPacks = false;

  init(VoidCallback callback) async {
    if (_isInitialized) {
      callback();
      return;
    }
    prependViewTypes.add(VIEW_TYPE_PACK_HEADER);

    _hasUnsubmittedPacks = await Location.hasUnsubmittedPacks(this.locationId);
    _isInitialized = true;
    callback();

    final watcher = await SyncEngine.current().watchSchemas([PackEntry.SCHEMA_NAME]);
    final sub = watcher.listen((event) async {
      final newHasUnsubmittedPacks = await Location.hasUnsubmittedPacks(this.locationId);
      if (isDisposed) {
        return;
      }
      if (newHasUnsubmittedPacks != _hasUnsubmittedPacks) {
        _hasUnsubmittedPacks = newHasUnsubmittedPacks;
        notifyListeners();
      }
    });

    this.registerSubscription(sub);
  }

  LocationPackObjectListController(int locationId, this.useWarehouseOrder)
      : super(
            locationId,
            useWarehouseOrder
                ? LocationCoilStockWhOrderDatasource(locationId)
                : LocationCoilStockDatasource(locationId, prodRequired: true, activeCoilsOnly: true)) {
    if (!this.useWarehouseOrder) {
      setGroupByColumn("tray_id");
    }
  }

  int? getPackUnitCount({int? renderIndex, int? datasourceIndex}) {
    int? packUnitCount = getDatasourceValueAt<int>("pack_units_count",
        renderIndex: renderIndex, datasourceIndex: datasourceIndex); // previous pack
    if ((packUnitCount ?? 0) <= 0) {
      packUnitCount = null;
    }
    if (packUnitCount != null) {
      return packUnitCount;
    }
    return getDefaultPackUnitCount(renderIndex: renderIndex, datasourceIndex: datasourceIndex);
  }

  int? getDefaultPackUnitCount({int? renderIndex, int? datasourceIndex}) {
    var currentFill = getDatasourceValueAt("current_fill", renderIndex: renderIndex, datasourceIndex: datasourceIndex);
    if (currentFill != null && currentFill < 0) {
      currentFill = 0;
    }
    final parValue = getDatasourceValueAt("par_value", renderIndex: renderIndex, datasourceIndex: datasourceIndex);
    if (currentFill != null && parValue != null) {
      return max(parValue - currentFill, 0);
    }
    return null;
  }

  createPack(_LocationsPackTabState state) async {
    late final Pack? pack;
    if (this.useWarehouseOrder) {
      pack = await _getProductPackData();
    } else {
      pack = await _getCoilPackData();
    }

    if (pack?.entries?.isEmpty ?? true) {
      Fluttertoast.showToast(msg: "No pack values to save");
      return;
    }

    final res = await SyncEngine.current().upsertObject(pack!);
    print(res);

    if (res.isSuccessful) {
      Fluttertoast.showToast(msg: "Pack created successfully.");
    } else {
      Fluttertoast.showToast(msg: res.primaryErrorMessage("Pack save error"));
    }

    this.dataSource.reload(
      callback: () {
        this.resetValues();
      },
    );
  }

  Future<Pack?> _getCoilPackData() async {
    final pack = Pack();
    pack.locationId = locationId;
    pack.entries = [];
    final packEntries = pack.entries!;

    for (var dsIndex = 0; dsIndex < this.datasourceCount; dsIndex++) {
      final coilId = getObjectId(datasourceIndex: dsIndex);
      final packUnitCount = hasUnitCount(coilId) ? getUnitCount(coilId) : getPackUnitCount(datasourceIndex: dsIndex);
      if (packUnitCount == null || packUnitCount <= 0) {
        continue;
      }
      final row = this.dataSource.getItemAt(dsIndex)!;
      final int productId = row.getValueAt(columnName: "product_id");

      final packEntry = PackEntry();
      packEntry.locationId = this.locationId;
      packEntry.productId = productId;
      packEntry.coilId = coilId;
      packEntry.unitCount = packUnitCount;

      packEntries.add(packEntry);
    }

    return pack;
  }

  Future<Pack?> _getProductPackData() async {
    final locationCoils = (await SyncEngine.current().select(
            "select * from ${Coil.schema.tableName} where active = 1 and location_id=?",
            args: [this.locationId]))
        .mapOf(Coil.schema)
        .toList();

    final coilsMap = HashMap<int, List<Coil>>();

    for (final coil in locationCoils) {
      final productId = coil.productId;
      if (productId == null) {
        continue;
      }
      if (!coilsMap.containsKey(coil.productId)) {
        coilsMap[productId] = [coil];
      } else {
        coilsMap[productId]!.add(coil);
      }
    }

    Map<Coil, int> coilPacks = HashMap();
    final addPackUnits = (Coil coil, int unitCount) {
      if (unitCount > 0) {
        int prevCount = 0;
        if (coilPacks.containsKey(coil)) {
          prevCount = coilPacks[coil]!;
        }
        coilPacks[coil] = prevCount + unitCount;
        coil.lastFill = (coil.lastFill ?? 0) + unitCount;
      }
    };

    for (var dsIndex = 0; dsIndex < this.datasourceCount; dsIndex++) {
      final productId = getObjectId(datasourceIndex: dsIndex);

      final defPackUnitCount =
          hasUnitCount(productId) ? getUnitCount(productId) : getPackUnitCount(datasourceIndex: dsIndex);
      if (defPackUnitCount == null || defPackUnitCount <= 0) {
        continue;
      }

      final coilsForProduct = coilsMap[productId] ?? [];
      if (coilsForProduct.isEmpty) {
        continue;
      }

      coilsForProduct.sort((o1, o2) {
        final diff = o1.displayName!.length - o2.displayName!.length;
        if (diff == 0) {
          return o1.displayName!.compareTo(o2.displayName!);
        }
        return diff;
      });

      var checkOnlyNotFull = true;

      var packUnitCount = defPackUnitCount;

      while (packUnitCount > 0) {
        double totalFillUnitCount = 0;
        double totalParValue = 0;
        List<Pair<Coil, double>> candidates = [];

        for (final coil in coilsForProduct) {
          double fillPercent = coil.getFillPercent();
          if (checkOnlyNotFull && fillPercent >= 1) {
            continue;
          }
          candidates.add(Pair(coil, fillPercent));
          totalFillUnitCount += coil.lastFill ?? 0;
          totalParValue += coil.getParValue();
        }

        double targetFillPercent = (totalFillUnitCount + packUnitCount) / totalParValue;
        if (checkOnlyNotFull && targetFillPercent > 1) {
          targetFillPercent = 1;
        }

        // sort the coils desc by their fill percent
        candidates.sort((o1, o2) {
          if (o1.right == o2.right) {
            return coilsForProduct.indexOf(o1.left).compareTo(coilsForProduct.indexOf(o2.left));
          }
          return o1.right.compareTo(o2.right);
        });

        for (final mem in candidates) {
          final coil = mem.left;
          double unitPercent = 1.toDouble() / coil.getParValue();

          int addUnitCount = ((targetFillPercent - coil.getFillPercent()) / unitPercent).floor();
          addUnitCount = max(min(addUnitCount, packUnitCount), 1);
          addPackUnits(coil, addUnitCount);
          packUnitCount -= addUnitCount;
          if (packUnitCount == 0) {
            break;
          }
        }

        // we want to run this loop twice
        // once just for the elements which are not yet full
        // second time for any elements
        if (checkOnlyNotFull) {
          checkOnlyNotFull = false;
        } else {
          break;
        }
      }

      addPackUnits(coilsForProduct.first, packUnitCount);
    }

    final List<PackEntry> packEntries = [];

    for (final coil in coilPacks.keys) {
      final packValue = coilPacks[coil]!;
      final packEntry = PackEntry();
      packEntry.coilId = coil.id;
      packEntry.productId = coil.productId;
      packEntry.locationId = locationId;
      packEntry.unitCount = packValue;
      packEntries.add(packEntry);
    }

    final pack = Pack();
    pack.locationId = locationId;
    pack.entries = packEntries;

    return pack;
  }

  @override
  Widget buildBodyRow(BuildContext context, int viewType, int renderIndex) {
    switch (viewType) {
      case VIEW_TYPE_PACK_HEADER:
        return _buildCachePackAlert(context);
      default:
        return super.buildBodyRow(context, viewType, renderIndex);
    }
  }

  Widget _buildCachePackAlert(BuildContext context) {
    return PackHeaderWidget(
      hasPreviousPacks: _hasUnsubmittedPacks,
      onReset: () async {
        final pack = Pack();
        pack.locationId = locationId;
        final res = await SyncEngine.current().mutateObject(pack, SyncObjectMutationType.Delete);
        if (res.isSuccessful) {
          Fluttertoast.showToast(msg: "Packs deleted");
          this.dataSource.reload();
        } else {
          Fluttertoast.showToast(msg: res.primaryErrorMessage("Error deleting packs"));
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class PackHeaderWidget extends StatefulWidget {
  final VoidCallback onReset;
  final bool hasPreviousPacks;

  PackHeaderWidget({Key? key, required this.hasPreviousPacks, required this.onReset}) : super(key: key);

  @override
  _PackHeaderWidgetState createState() {
    return _PackHeaderWidgetState();
  }
}

class _PackHeaderWidgetState extends State<PackHeaderWidget> {
  var _isExpanded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = Colors.white;

    final titleTextStyle = TextStyle(
      color: textColor,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    );

    final List<Widget> widgets = [];

    if (widget.hasPreviousPacks) {
      widgets.addAll([
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              "Cached Pack Alert",
              style: titleTextStyle,
            ),
            Icon(
              Icons.info_outline,
              color: textColor,
            )
          ]),
        )
      ]);

      if (_isExpanded) {
        widgets.addAll([
          Divider(
            color: theme.primaryColorLight,
          ),
          Text(
            "There is a cached Pack-submission on this device without an associated Stock submission.\nPress Dismiss to add more items to the cached Pack or press Reset to start a new Pack for this machine.",
            style: TextStyle(color: textColor),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MaterialButton(
                onPressed: () {
                  _isExpanded = false;
                  this.widget.onReset();
                },
                child: Text(
                  "RESET",
                  style: TextStyle(color: textColor.withOpacity(0.6)),
                ),
              ),
              MaterialButton(
                onPressed: () {
                  setState(() {
                    _isExpanded = false;
                  });
                },
                child: Text(
                  "DISMISS",
                  style: TextStyle(color: textColor.withOpacity(1)),
                ),
              )
            ],
          )
        ]);
      }
    } else {
      widgets.add(
        Text(
          "New Pack",
          style: titleTextStyle,
        ),
      );
    }

    return Container(
      color: theme.primaryColor,
      child: Padding(
        padding: EdgeInsets.only(left: 16, top: 16, right: 16, bottom: _isExpanded && widget.hasPreviousPacks ? 0 : 16),
        child: Column(
          children: widgets,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
      ),
    );
  }
}
