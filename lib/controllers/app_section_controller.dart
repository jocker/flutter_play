import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppSection {
  static const Dashboard = AppSection(
        "dashboard",
        "Dashboard",
        Icons.dashboard,
      ),
      Locations = AppSection("locations", "Locations", Icons.business),
      Warehouse = AppSection("warehouse", "Warehouse", Icons.event_note),
      Notes = AppSection("notes", "Notes", Icons.assignment),
      Settings = AppSection("settings", "Settings", Icons.settings);

  static const List<AppSection> ALL = [Dashboard, Locations, Warehouse, Notes, Settings];
  final String key;
  final String displayName;
  final IconData iconData;

  const AppSection(this.key, this.displayName, this.iconData);
}
