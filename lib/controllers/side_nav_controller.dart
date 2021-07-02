import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/constants/styles.dart';

typedef AppPageRoute = String;

const AppPageRoute OverviewPageRoute = "Overview",
    DriversPageRoute = "Drivers",
    ClientsPageRoute = "Clients",
    AuthenticationPageRoute = "Authentication";

List SideMenuItems = [
  OverviewPageRoute,
  DriversPageRoute,
  ClientsPageRoute,
  AuthenticationPageRoute
];

class SideNavController extends GetxController {
  static register() {
    Get.put(SideNavController());
  }

  static SideNavController get instance {
    return Get.find();
  }

  var _activeItem = RxString(OverviewPageRoute);
  var _hoverItem = RxString("");

  set activeItem(AppPageRoute newItem) {
    if (!isRouteActive(newItem)) {
      _activeItem.value = newItem;
    }
  }

  AppPageRoute get activeItem {
    return _activeItem.value;
  }

  bool isRouteActive(AppPageRoute item) {
    return _activeItem.value == item;
  }

  bool isRouteHover(AppPageRoute item) {
    return _hoverItem.value == item;
  }

  void onItemHover(AppPageRoute item, bool hovered) {
    if (hovered) {
      if (!isRouteHover(item)) {
        _hoverItem.value = item;
      }
    } else if (isRouteHover(item)) {
      _hoverItem.value = "";
    }
  }

  void onItemTap(AppPageRoute item) {}

  Widget makeIcon(AppPageRoute route) {
    double size = 16;
    var color = lightGrey;

    if (isRouteActive(route)) {
      size = 22;
      color = dark;
    } else if (isRouteHover(route)) {
      color = dark;
    }

    late IconData iconData;

    switch (route) {
      case OverviewPageRoute:
        iconData = Icons.trending_up;
        break;
      case DriversPageRoute:
        iconData = Icons.drive_eta;
        break;
      case ClientsPageRoute:
        iconData = Icons.people_alt_outlined;
        break;
      case AuthenticationPageRoute:
        iconData = Icons.exit_to_app;
        break;
      default:
        iconData = Icons.exit_to_app;
        break;
    }

    return Icon(iconData, size: size, color: color);
  }
}
