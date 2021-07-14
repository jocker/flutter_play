import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSectionController extends GetxController {
  static register() {
    Get.put(AppSectionController());
  }

  static AppSectionController get instance {
    return Get.find();
  }

  var _activeItem = AppSection.Dashboard.obs;

  set activeItem(AppSection newItem) {
    if (!isRouteActive(newItem)) {
      _activeItem.value = newItem;
    }
  }

  AppSection get activeItem {
    return _activeItem.value;
  }

  bool isRouteActive(AppSection other) {
    return _activeItem.value == other;
  }

  void onItemTap(AppSection item) {}

  Widget makeSideMenuItem(BuildContext ctx, AppSection route) {
    double size = 22;
    final theme = Theme.of(ctx);
    var color = theme.primaryColor;

    if (isRouteActive(route)) {
      size = 22;
      color = theme.accentColor;
    }

    return Icon(route.iconData, size: size, color: color);
  }
}

class AppSection {
  static const Dashboard = AppSection("dashboard", "Dashboard", Icons.dashboard),
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
