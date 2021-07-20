import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vgbnd/pages/overview/overview.dart';

import 'locations_common.dart';
import 'locations_pack_tab.dart';
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

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
      } else if (wasChangingIndex == index) {
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

class LocationsOverview extends StatelessWidget {
  final locationId = 231265;
  final _controllers = HashMap<String, dynamic>();

  @override
  Widget build(BuildContext context) {
    return TabPanel(
      tabs: [
        TabConfig(
          key: "view",
          label: "VIEW",
          build: (context) {
            return LocationViewTab(
              locationId,
              getOrInitController("view")
            );
          },
        ),
        TabConfig(
          key: "pack",
          label: "PACK",
          build: (context) {
            return LocationsPackTab(locationId, getOrInitController("pack"));
          },
        ),
        TabConfig(
          key: "stock",
          label: "STOCK",
          build: (context) {
            return OverviewPage();
            return Center(
              child: Text("STOCK"),
            );
          },
        )
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
        ctrl = (LocationObjectListController(LocationCoilStockDatasource(locationId, false))..setGroupByColumn("tray_id"));
        break;
      case "pack":
        ctrl = (LocationObjectListController(LocationCoilStockDatasource(locationId, true ))..setGroupByColumn("tray_id"));
        break;
    }

    if (ctrl == null) {
      throw Exception("Don't know how to create controller $which");
    }
    _controllers[which] = ctrl;
    return ctrl;
  }
}
