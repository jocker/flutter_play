import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/controllers/app_section_controller.dart';

class RoutingController extends GetxController {
  final GlobalKey<NavigatorState> routingKey = GlobalKey();

  static RoutingController get instance {
    return Get.find();
  }

  static register() {
    Get.put(RoutingController());
  }

  Future<dynamic> navigateTo(AppSection route) {
    return routingKey.currentState!.pushNamed(route.key);
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
