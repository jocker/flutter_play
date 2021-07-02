import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vgbnd/controllers/side_nav_controller.dart';
import 'package:vgbnd/pages/overview/overview.dart';
import 'package:vgbnd/widgets/side_nav_item.dart';

class LargeScreen extends StatelessWidget {
  LargeScreen() : super();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.red,
            child: Column(
              children: [
                SideNavItem(
                  route: OverviewPageRoute,
                  onTap: () {},
                ),
                SideNavItem(
                  route: DriversPageRoute,
                  onTap: () {},
                ),
                SideNavItem(
                  route: ClientsPageRoute,
                  onTap: () {},
                )
              ],
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: OverviewPage()
        )
      ],
    );
  }
}
