import 'package:flutter/material.dart';
import 'package:vgbnd/widgets/large_screen.dart';
import 'package:vgbnd/widgets/small_screen.dart';
import 'package:vgbnd/widgets/top_nav.dart';

import 'helpers/responsiveness.dart';

class SiteLayout extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        appBar: buildTopNav(context, scaffoldKey),
        drawer: Drawer(),
        body: ResponsiveWidget(
          widgetFactory: (size) {
            switch (size) {
              case ScreenSize.Small:
                return SmallScreen();
              case ScreenSize.Large:
              case ScreenSize.Medium:
              case ScreenSize.Custom:
              default:
                return LargeScreen();
            }
          },
        ));
  }
}
