import 'package:dynamic_themes/dynamic_themes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vgbnd/controllers/app_section_controller.dart';
import 'package:vgbnd/pages/locations/locations_list.dart';

import 'constants/app_theme.dart';
import 'controllers/routing_controller.dart';
import 'layout.dart';

void main() {
  AppSectionController.register();
  RoutingController.register();
  LocationListPageController.register();

  runApp(MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    final dark = ThemeData.dark();
    final darkButtonTheme = dark.buttonTheme.copyWith(buttonColor: Colors.grey[700]);
    final darkFABTheme = dark.floatingActionButtonTheme;
    //0a549d
    final themeCollection = ThemeCollection(themes: {
      AppTheme.Blue: ThemeData(primarySwatch: AppTheme.blue, brightness: Brightness.light),
      AppTheme.Red: ThemeData(primarySwatch: AppTheme.red),
      AppTheme.Green: ThemeData(primarySwatch: AppTheme.green),
      AppTheme.Dark: dark.copyWith(
          accentColor: AppTheme.blue,
          buttonTheme: darkButtonTheme,
          floatingActionButtonTheme: darkFABTheme.copyWith(backgroundColor: AppTheme.blue)),
    });

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeCollection[AppTheme.Blue],
      home: SiteLayout(),
    );
  }
}
