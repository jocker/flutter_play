import 'package:flutter/material.dart';
import 'package:vgbnd/controllers/app_section_controller.dart';
import 'package:vgbnd/controllers/routing_controller.dart';

Navigator routingNavigator() {
  return Navigator(
    key: RoutingController.instance.routingKey,
    initialRoute: AppSection.Dashboard.key,
  );
}
