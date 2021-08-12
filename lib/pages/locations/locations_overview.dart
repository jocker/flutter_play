import 'dart:async';
import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vgbnd/models/location.dart';
import 'package:vgbnd/sync/sync.dart';
import 'package:vgbnd/widgets/app_page_layout.dart';

import 'locations_common.dart';
import 'locations_pack_tab.dart';
import 'locations_stock_tab.dart';
import 'locations_view_tab.dart';

typedef Widget BuildTabFunc(BuildContext context);

class TabConfig {
  final String key;
  final String label;
  final BuildTabFunc build;

  const TabConfig({required this.key, required this.label, required this.build});
}

class TabPanel extends StatefulWidget {
  final List<TabConfig> tabs;

  TabPanel({required this.tabs});

  @override
  State<StatefulWidget> createState() {
    return _TabPanelState();
  }
}

class _TabPanelState extends State<TabPanel> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final _renderedTabs = new HashSet<String>();

  @override
  void initState() {
    super.initState();
    _renderedTabs.add(widget.tabs[0].key);
    _tabController = TabController(vsync: this, length: this.widget.tabs.length);
    int wasChangingIndex = -1;
    _tabController.addListener(() {
      final index = _tabController.index;
      final previousIndex = _tabController.previousIndex;
      final isChanging = _tabController.indexIsChanging;
      if (isChanging) {
        wasChangingIndex = index;
      } else {
        final tab = this.widget.tabs[index];
        if (!_renderedTabs.contains(tab.key)) {
          setState(() {
            _renderedTabs.add(tab.key);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          color: theme.primaryColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            tabs: this.widget.tabs.map((e) {
              return Tab(text: e.label);
            }).toList(),
          ),
        ),
        Expanded(
            child: TabBarView(
          controller: _tabController,
          children: this.widget.tabs.map((tab) {
            if (_renderedTabs.contains(tab.key)) {
              return tab.build(context);
            } else {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
          }).toList(),
        ))
      ],
    );
  }
}

class LocationsOverview extends StatefulWidget {
  final int locationId;

  LocationsOverview({required this.locationId});

  @override
  _LocationsOverviewState createState() => _LocationsOverviewState();
}

class _LocationsOverviewState extends State<LocationsOverview> {
  final _controllers = HashMap<String, LocationObjectListController>();

  String _title = "Overview";

  @override
  void initState() {
    super.initState();

    scheduleMicrotask(() async {
      final Location? location = await SyncController.current().loadObject(Location.schema, id: this.widget.locationId);
      if (mounted) {
        setState(() {
          _title = location?.locationName ?? _title;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageLayout(title: _title, body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    return TabPanel(
      tabs: [
        TabConfig(
          key: "view",
          label: "VIEW",
          build: (context) {
            return LocationViewTab(getOrInitController("view"));
          },
        ),
        TabConfig(
          key: "pack",
          label: "PACK",
          build: (context) {
            return LocationsPackTab(getOrInitController("pack"));
          },
        ),
        TabConfig(
          key: "stock",
          label: "STOCK",
          build: (context) {
            return LocationsStockTab(getOrInitController("stock"));
            return Center(
              child: Text("STOCK"),
            );
          },
        ),
      ],
    );
  }

  dynamic getOrInitController(String which) {
    if (_controllers.containsKey(which)) {
      return _controllers[which];
    }

    dynamic ctrl;
    switch (which) {
      case "view":
        ctrl = (LocationObjectListController(widget.locationId,
            LocationCoilStockDatasource(widget.locationId, activeCoilsOnly: false, prodRequired: false))
          ..setGroupByColumn("tray_id"));
        break;
      case "pack":
        ctrl = (LocationPackObjectListController(widget.locationId, false));
        break;
      case "stock":
        ctrl = (LocationStockObjectListController(widget.locationId));
        break;
    }

    if (ctrl == null) {
      throw Exception("Don't know how to create controller $which");
    }
    _controllers[which] = ctrl;
    return ctrl;
  }

  @override
  void dispose() {
    super.dispose();
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _controllers.clear();
  }
}
