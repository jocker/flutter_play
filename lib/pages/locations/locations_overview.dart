import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vgbnd/pages/overview/overview.dart';

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

class _TabPanelState extends State<TabPanel> with SingleTickerProviderStateMixin {
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
      } else if (wasChangingIndex == index) {
        final tab = this.widget.tabs[index];
        if (!_renderedTabs.contains(tab.key)) {
          setState(() {
            _renderedTabs.add(tab.key);
          });
        }
        print("activate index $index");
      }
      print("X index=$index previousIndex=$previousIndex isChanging=$isChanging");
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
  @override
  Widget build(BuildContext context) {
    return TabPanel(
      tabs: [
        TabConfig(
          key: "view",
          label: "VIEW",
          build: (context) {
            return LocationViewTab();
          },
        ),
        TabConfig(
          key: "pack",
          label: "PACK",
          build: (context) {
            return OverviewPage();
          },
        ),
        TabConfig(
          key: "stock",
          label: "STOCK",
          build: (context) {
            return Center(
              child: Text("STOCK"),
            );
          },
        )
      ],
    );
  }
}
