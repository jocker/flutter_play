import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/controllers/side_nav_controller.dart';
import 'package:vgbnd/helpers/responsiveness.dart';

class SideNavItem extends StatelessWidget {
  final AppPageRoute route;
  final Function onTap;

  SideNavItem({required this.route, required this.onTap}) : super();

  @override
  Widget build(BuildContext context) {
    var screenSize = ScreenSize.of(context);

    SideNavController controller = Get.find();
    return InkWell(onHover: (value) {
      controller.onItemHover(route, value);
    }, onTap: () {
      controller.onItemTap(route);
    }, child: Obx(() {
      return Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: controller.makeIcon(this.route),
          ),
          Text(
            this.route,
            style: TextStyle(fontSize: 16),
          )
        ],
      );
    }));
  }
}
