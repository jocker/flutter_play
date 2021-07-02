import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vgbnd/controllers/side_nav_controller.dart';

import 'controllers/routing_controller.dart';
import 'layout.dart';

void main() {
  SideNavController.register();
  RoutingController.register();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme.apply(bodyColor: Colors.black);
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Dash",
      theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          textTheme: GoogleFonts.robotoMonoTextTheme(textTheme),
          primaryColor: Colors.blue,
          pageTransitionsTheme: PageTransitionsTheme(builders: {})),
      home: SiteLayout(),
    );
  }
}
