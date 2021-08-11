import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/api/api.dart';
import 'package:vgbnd/controllers/app_section_controller.dart';
import 'package:vgbnd/pages/locations/locations_list.dart';
import 'package:vgbnd/widgets/top_nav.dart';

class SiteLayout extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = UserAccount.current;
    return Scaffold(
        key: scaffoldKey,
        appBar: buildTopNav(context, scaffoldKey),
        drawer: Drawer(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
                color: theme.primaryColor,
                padding: EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        textAlign: TextAlign.left,
                      ),
                      Text(
                        user.email,
                        textAlign: TextAlign.right,
                      )
                    ],
                  ),
                )),
            Column(
              children: AppSection.ALL.map((appSection) => _makeSizeMenuItem(context, appSection)).toList(),
            ),
            Divider(),
            MaterialButton(
                child: Text("Log out", style: TextStyle(color: theme.primaryColor, fontSize: 16)), onPressed: () {})
          ],
        )),
        body: LocationsList());
  }
}

Widget _makeSizeMenuItem(BuildContext context, AppSection appSection) {
  AppSectionController controller = Get.find();

  double size = 16;
  final theme = Theme.of(context);
  var color = theme.primaryColor;

  if (controller.isRouteActive(appSection)) {
    size = 30;
  }

  return InkWell(
      onTap: () {
        controller.onItemTap(appSection);
      },
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Icon(appSection.iconData, size: size, color: color),
          ),
          Text(
            appSection.displayName,
            style: TextStyle(fontSize: 16, color: theme.primaryColor),
          )
        ],
      ));
}
