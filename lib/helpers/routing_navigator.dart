import 'package:flutter/material.dart';
import 'package:vgbnd/controllers/routing_controller.dart';
import 'package:vgbnd/controllers/side_nav_controller.dart';

Navigator routingNavigator() {
  return Navigator(
    key: RoutingController.instance.routingKey,
    initialRoute: OverviewPageRoute,
  );
}
