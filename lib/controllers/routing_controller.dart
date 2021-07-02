import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/controllers/side_nav_controller.dart';

class RoutingController extends GetxController {
  final GlobalKey<NavigatorState> routingKey = GlobalKey();

  static RoutingController get instance {
    return Get.find();
  }

  static register() {
    Get.put(RoutingController());
  }

  Future<dynamic> navigateTo(AppPageRoute route) {
    return routingKey.currentState!.pushNamed(route);
  }

  bool goBack() {
    var rState = routingKey.currentState;
    if (rState == null) {
      return false;
    }

    if (!rState.canPop()) {
      return false;
    }

    rState.pop();
    return true;
  }
}
